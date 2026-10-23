// ضع مفتاحك هنا مباشرة كما طلبَت
const GEMINI_API_KEY = "AQ.Ab8RN6KQJfDb-GAuOKPBQqg_425wHCpg2KTL7H6u2Fg33OYF3g";

async function askAI(promptText) {
    const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${GEMINI_API_KEY}`;
    
    try {
        const response = await fetch(url, {
            method: "POST",
            headers: {
                "Content-Type": "application/json"
            },
            body: JSON.stringify({
                contents: [{
                    parts: [{ text: promptText }]
                }]
            })
        });

        const data = await response.json();
        
        // استخراج الإجابة من رد جوجل
        const aiResponse = data.candidates[0].content.parts[0].text;
        return aiResponse;

    } catch (error) {
        console.error("حدث خطأ في الاتصال بالذكاء الاصطناعي:", error);
        return "عذراً، حدث خطأ أثناء معالجة طلبك.";
    }
}
