import OpenAI from "openai";

const client = new OpenAI({
  apiKey: process.env.XAI_API_KEY,
  baseURL: "https://api.x.ai/v1"
});

export default async function handler(req, res) {
  if (req.method !== "POST") {
    return res.status(405).json({ error: "Method not allowed" });
  }

  if (!process.env.XAI_API_KEY) {
    return res.status(503).json({
      error: "Grok is not configured. Set XAI_API_KEY on the server."
    });
  }

  try {
    const { messages, model = "grok-4.7" } = req.body || {};

    if (!Array.isArray(messages) || messages.length === 0) {
      return res.status(400).json({ error: "messages must be a non-empty array" });
    }

    const response = await client.responses.create({
      model,
      input: messages.map(m => ({
        role: m.role,
        content: String(m.content ?? "")
      }))
    });

    return res.status(200).json({
      output: response.output_text || "",
      model
    });
  } catch (error) {
    console.error("xAI request failed:", error);
    return res.status(500).json({
      error: error?.message || "The Grok request failed."
    });
  }
}
