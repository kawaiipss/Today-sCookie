const { onRequest } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const https = require("https");

initializeApp();

const claudeApiKey = defineSecret("CLAUDE_API_KEY");

function getTodayKey() {
  const kst = new Date(Date.now() + 9 * 60 * 60 * 1000);
  const y = kst.getUTCFullYear();
  const m = String(kst.getUTCMonth() + 1).padStart(2, "0");
  const d = String(kst.getUTCDate()).padStart(2, "0");
  return `${y}${m}${d}`;
}

exports.getDailyFortune = onRequest(
  { region: "asia-northeast3", secrets: [claudeApiKey], invoker: "public" },
  async (req, res) => {
    if (req.method !== "POST") {
      return res.status(405).send("Method Not Allowed");
    }

    const uid = req.body?.uid;
    if (!uid) {
      return res.status(400).json({ error: "UID required" });
    }

    try {
      const dateKey = getTodayKey();
      const db = getFirestore();
      const docRef = db.collection("dailyFortunes").doc(`${uid}_${dateKey}`);

      res.set("Content-Type", "application/json; charset=utf-8");

      const doc = await docRef.get();
      if (doc.exists) {
        return res.json({ fortune: doc.data().fortune, cached: true });
      }

      const fortune = await callClaude(claudeApiKey.value().trim(), dateKey);
      await docRef.set({
        uid,
        date: dateKey,
        fortune,
        createdAt: FieldValue.serverTimestamp(),
      });

      return res.json({ fortune, cached: false });
    } catch (e) {
      console.error("getDailyFortune error:", e);
      return res.status(500).json({ error: "Internal error" });
    }
  }
);

const THEMES = ["인간관계", "재물", "건강", "직장/사업"];
const KEYWORDS = [
  "기회", "인연", "변화", "조화", "균형", "인내", "소통", "신중", "흐름", "귀인",
];

function pickRandom(arr, count) {
  const pool = [...arr];
  const picked = [];
  for (let i = 0; i < count && pool.length > 0; i++) {
    const idx = Math.floor(Math.random() * pool.length);
    picked.push(pool.splice(idx, 1)[0]);
  }
  return picked;
}

async function callClaude(apiKey, dateKey) {
  const year = dateKey.slice(0, 4);
  const month = parseInt(dateKey.slice(4, 6));
  const day = parseInt(dateKey.slice(6, 8));

  const theme = pickRandom(THEMES, 1)[0];
  const keywords = pickRandom(KEYWORDS, 1 + Math.round(Math.random()));

  const prompt =
    `오늘은 ${year}년 ${month}월 ${day}일입니다. ` +
    `오늘 하루에 대한 포츈쿠키 운세 문구를 한 문장으로 작성해줘.\n\n` +
    `다음 규칙을 반드시 따를 것:\n` +
    `1. "오늘"로 시작하고, "~것이다", "~이 찾아온다", "~날이 될 것이다" 같은 예언형 어조로 끝낼 것\n` +
    `2. 누구에게나 해당될 수 있는 모호하고 보편적인 표현을 쓸 것 (너무 구체적인 상황은 피할 것)\n` +
    `3. 약한 경고나 조심의 뉘앙스로 시작해 희망적인 결말로 마무리할 것 (예: "~을 조심해야 하나, ~이 따를 것이다")\n` +
    `4. 반드시 "${theme}" 영역을 주제로 삼을 것 (다른 영역은 언급하지 말 것)\n` +
    `5. "서두르지 말 것", "주변을 살필 것" 같은 짧은 행동 지침을 자연스럽게 녹여 넣을 것\n` +
    `6. 다음 키워드를 반드시 활용할 것: ${keywords.join(", ")}\n\n` +
    `따옴표나 부연 설명 없이 문장 하나만 출력해.`;

  const body = JSON.stringify({
    model: "claude-sonnet-4-6",
    max_tokens: 200,
    messages: [{ role: "user", content: prompt }],
  });

  return new Promise((resolve, reject) => {
    const req = https.request(
      {
        hostname: "api.anthropic.com",
        path: "/v1/messages",
        method: "POST",
        headers: {
          "x-api-key": apiKey,
          "anthropic-version": "2023-06-01",
          "content-type": "application/json",
          "content-length": Buffer.byteLength(body),
        },
      },
      (res) => {
        const chunks = [];
        res.on("data", (chunk) => chunks.push(chunk));
        res.on("end", () => {
          try {
            const data = Buffer.concat(chunks).toString("utf8");
            const parsed = JSON.parse(data);
            if (res.statusCode !== 200) {
              console.error(`Claude API ${res.statusCode}:`, data);
              reject(new Error(`Claude API error: ${res.statusCode}`));
              return;
            }
            resolve(parsed.content[0].text.trim());
          } catch (_) {
            reject(new Error("Failed to parse Claude response"));
          }
        });
      }
    );
    req.on("error", (e) => reject(new Error(`Network error: ${e.message}`)));
    req.write(body);
    req.end();
  });
}
