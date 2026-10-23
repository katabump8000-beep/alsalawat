export async function onRequestPost(context) {
  try {
    const { request, env } = context;
    if (!env.GEMINI_API_KEY) {
      return Response.json({ error: "Missing server secret GEMINI_API_KEY" }, { status: 500 });
    }
    const body = await request.json();
    const question = typeof body.question === "string" ? body.question.trim() : "";
    const subject = typeof body.subject === "string" ? body.subject.trim() : "الدراسة";
    if (!question) return Response.json({ error: "اكتب سؤالاً أولاً." }, { status: 400 });
    if (question.length > 8000) return Response.json({ error: "السؤال طويل جداً." }, { status: 400 });

    const prompt = `أنت مساعد دراسي عربي لطالب يستعد للبكالوريا. أجب باللغة العربية الواضحة وبأسلوب تعليمي مناسب للمرحلة الثانوية. في الأسئلة المدرسية، اشرح الخطوات ولا تختلق معلومات. المادة المختارة: ${subject}\n\nسؤال الطالب:\n${question}`;
    const upstream = await fetch(
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-goog-api-key": env.GEMINI_API_KEY
        },
        body: JSON.stringify({
          contents: [{ role: "user", parts: [{ text: prompt }] }],
          generationConfig: { temperature: 0.6, maxOutputTokens: 1800 }
        })
      }
    );
    const result = await upstream.json();
    if (!upstream.ok) {
      return Response.json({ error: "تعذر الحصول على إجابة من Gemini. تحقق من المفتاح وإعدادات الخدمة." }, { status: upstream.status });
    }
    const answer = result?.candidates?.[0]?.content?.parts?.map(p => p.text || "").join("").trim();
    if (!answer) return Response.json({ error: "لم يصل ردّ نصي من Gemini." }, { status: 502 });
    return Response.json({ answer }, { headers: { "Cache-Control": "no-store" } });
  } catch (error) {
    return Response.json({ error: "حدث خطأ في معالجة السؤال." }, { status: 500 });
  }
}
