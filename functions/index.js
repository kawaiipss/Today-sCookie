const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const https = require("https");

initializeApp();

const claudeApiKey = defineSecret("CLAUDE_API_KEY");

// KST(UTC+9) 기준 오늘 날짜 키 — 한국 유저의 자정 기준과 일치
function getTodayKey() {
  const kst = new Date(Date.now() + 9 * 60 * 60 * 1000);
  const y = kst.getUTCFullYear();
  const m = String(kst.getUTCMonth() + 1).padStart(2, "0");
  const d = String(kst.getUTCDate()).padStart(2, "0");
  return `${y}${m}${d}`;
}

exports.getDailyFortune = onCall(
  { region: "asia-northeast3", secrets: [claudeApiKey] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "인증이 필요합니다.");
    }

    const uid = request.auth.uid;
    const dateKey = getTodayKey();
    const db = getFirestore();
    const docRef = db.collection("dailyFortunes").doc(`${uid}_${dateKey}`);

    // 오늘 이미 생성된 운세가 있으면 캐시 반환 (하루 1회 제한)
    const doc = await docRef.get();
    if (doc.exists) {
      return { fortune: doc.data().fortune, cached: true };
    }

    const fortune = await callClaude(claudeApiKey.value(), dateKey);

    await docRef.set({
      uid,
      date: dateKey,
      fortune,
      createdAt: FieldValue.serverTimestamp(),
    });

    return { fortune, cached: false };
  }
);

async function callClaude(apiKey, dateKey) {
  const year = dateKey.slice(0, 4);
  const month = parseInt(dateKey.slice(4, 6));
  const day = parseInt(dateKey.slice(6, 8));

  const prompt =
    `오늘은 ${year}년 ${month}월 ${day}일입니다. ` +
    `오늘 날짜에 어울리는 포츈쿠키 운세 문구를 한 문장으로 써줘. ` +
    `짧고 따뜻하며 영감을 주는 한국어 문장 하나만 출력해. ` +
    `사랑, 재물, 건강, 도전, 인연, 성장 등 다양한 주제 중 오늘에 맞는 것으로 써줘. ` +
    `다른 설명이나 따옴표 없이 문장만 출력해.`;

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
        let data = "";
        res.on("data", (chunk) => (data += chunk));
        res.on("end", () => {
          try {
            const parsed = JSON.parse(data);
            if (res.statusCode !== 200) {
              reject(new HttpsError("internal", `Claude API error: ${res.statusCode}`));
              return;
            }
            resolve(parsed.content[0].text.trim());
          } catch (_) {
            reject(new HttpsError("internal", "Failed to parse Claude response"));
          }
        });
      }
    );
    req.on("error", (e) =>
      reject(new HttpsError("internal", `Network error: ${e.message}`))
    );
    req.write(body);
    req.end();
  });
}
