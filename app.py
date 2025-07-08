from dotenv import load_dotenv
from openai import OpenAI
import os
from wiki_util import get_wikipedia_context
import requests
from flask import Flask, request, jsonify
from flask_cors import CORS
from llm_handler import get_llm_response
from transformers import pipeline
from lettucedetect.models.inference import HallucinationDetector
#Current technologies used: Flutter, Flask, openAI API, together.ai LLM API, Wikipedia API (RAG), Hallucination detection HuggingFace models
load_dotenv()
client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))
together_api_key = os.getenv("TOGETHER_AI_KEY")
TOGETHER_API_URL = "https://api.together.xyz/v1/chat/completions"

app = Flask(__name__)
CORS(app)


# --                        --#
hallucination_detector = pipeline(
    "text-classification",
    model="Varun-Chowdary/hallucination_detect"  # or other model
)

def detect_hallucination(text):
    result = hallucination_detector(text, truncation=True)
    label = result[0]["label"]
    score = round(result[0]["score"], 3)
    return {"label": label, "score": score}
# --                        --#

detector = HallucinationDetector(
    method="transformer",
    model_path="KRLabsOrg/lettucedect-base-modernbert-en-v1"
)

@app.route('/query', methods=['POST'])
def query():
    data = request.get_json()
    user_question = data.get('input', '')

    # 1. Get Wikipedia context
    context = get_wikipedia_context(user_question)

    # 2. Format RAG prompt
    prompt = f"""
        Context:
        {context}

        Question:
        {user_question}

        Answer:
        """

    responses = {}

    # --- OpenAI Response ---
    try:
        openai_response = client.chat.completions.create(
            model="gpt-3.5-turbo",
            messages=[
                {"role": "system", "content": "Use the provided context to answer the question, and keep responses less than 4 sentences."},
                {"role": "user", "content": prompt}
            ]
        )
        responses["openai"] = openai_response.choices[0].message.content
    except Exception as e:
        responses["openai"] = f"Error from OpenAI: {str(e)}"

    # --- Together.ai Response ---
    try:
        headers = {
            "Authorization": f"Bearer {together_api_key}",
            "Content-Type": "application/json",
        }
        json_data = {
            "model": "meta-llama/Llama-Vision-Free",  # updated model name
            "messages": [
                {"role": "system", "content": "Use the provided context to answer the question, and keep responses less than 4 sentences."},
                {"role": "user", "content": prompt}
            ],
        "temperature": 0.7,
        "max_tokens": 512
        }

    # --                    -- #

        together_response = requests.post(TOGETHER_API_URL, headers=headers, json=json_data)
        if together_response.status_code == 200:
            responses["together"] = together_response.json()["choices"][0]["message"]["content"]
        else:
            responses["together"] = f"Error: {together_response.status_code} {together_response.text}"
    except Exception as e:
        responses["together"] = f"Error from Together.ai: {str(e)}"

    # --                    -- #


    responses["hallucination_openai"] = detect_hallucination(responses["openai"]) 
    responses["hallucination_together"] = detect_hallucination(responses["together"])

    # --                    -- #

    try:
        spans_openai = detector.predict(
            context=[context],
            question=user_question,
            answer=responses["openai"],
            output_format="spans"
        )
        responses["hallucination_spans_openai"] = spans_openai
    except Exception as e:
        responses["hallucination_spans_openai"] = []
        print(f"Span detection failed for OpenAI: {e}")

    try:
        spans_together = detector.predict(
            context=[context],
            question=user_question,
            answer=responses["together"],
            output_format="spans"
        )
        responses["hallucination_spans_together"] = spans_together
    except Exception as e:
        responses["hallucination_spans_together"] = []
        print(f"Span detection failed for Together.ai: {e}")


    return jsonify(responses)




@app.route('/improve_query', methods=['POST'])
def improve_query():
    data = request.get_json()
    user_question = data.get('input', '')
    if not user_question:
        return jsonify({"error": "No input provided"}), 400

    improved_prompt = f"""
Improve the following query to be more precise, longer, and more detailed, ensuring to mark all points to avoid hallucination. Make sure to back up the answer with sources and references. It cannot be more than 3 sentences. CANNOT BE MORE THAN 3 SENTENCES.

Original query: "{user_question}"

Please rewrite the query accordingly.
"""

    try:
        response = client.chat.completions.create(
            model="gpt-3.5-turbo",
            messages=[
                {"role": "system", "content": "You are a helpful assistant."},
                {"role": "user", "content": improved_prompt}
            ]
        )
        improved_query = response.choices[0].message.content
        return jsonify({"improved_query": improved_query})
    except Exception as e:
        return jsonify({"error": str(e)}), 500
    

if __name__ == '__main__':
    app.run(debug=True)