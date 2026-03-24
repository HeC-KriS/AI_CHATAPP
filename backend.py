from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import httpx
import uvicorn
from sqlalchemy import create_engine, Column, String, Text, DateTime
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
import datetime
import uuid
import os
from dotenv import load_dotenv
app = FastAPI()
load_dotenv()

# Get the URL from the environment
DATABASE_URL = os.getenv("DATABASE_URL")
#NEONDB SETUP

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

class Message(Base):
    __tablename__ = "messages"
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    thread_id = Column(String, index=True)
    user_id = Column(String, index=True)
    thread_name = Column(String)  
    role = Column(String) 
    content = Column(Text)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

Base.metadata.create_all(bind=engine)

DOCKER_ENDPOINT = "http://localhost:12434/v1/chat/completions"

class ChatRequest(BaseModel):
    prompt: str
    model_id: str
    thread_id: str
    user_id: str
    thread_name: str

@app.post("/chat")
async def chat_with_ai(req: ChatRequest):
    db = SessionLocal()
    try:
        #Save User Message
        db.add(Message(thread_id=req.thread_id, user_id=req.user_id, thread_name=req.thread_name, role="user", content=req.prompt))
        db.commit()

        #Fetch History for Context
        history = db.query(Message).filter(Message.thread_id == req.thread_id, Message.user_id == req.user_id).order_by(Message.created_at.desc()).limit(11).all()
        
        messages_for_ai = [{"role": "system", "content": "You are a helpful assistant. Use a friendly tone."}]
        for m in reversed(history):
            messages_for_ai.append({"role": m.role, "content": m.content})

        async with httpx.AsyncClient() as client:
            response = await client.post(DOCKER_ENDPOINT, json={"model": req.model_id, "messages": messages_for_ai, "temperature": 0.7}, timeout=120.0)

        ai_reply = response.json()["choices"][0]["message"]["content"]
        db.add(Message(thread_id=req.thread_id, user_id=req.user_id, thread_name=req.thread_name, role="assistant", content=ai_reply))
        db.commit()

        return {"reply": ai_reply}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        db.close()

@app.get("/threads/{user_id}")
async def get_user_threads(user_id: str):
    db = SessionLocal()
    try:
        #Returns pairs of thread_id, thread_name unique to this user
        result = db.query(Message.thread_id, Message.thread_name).filter(Message.user_id == user_id).distinct().all()
        return [{"id": r[0], "name": r[1]} for r in result]
    finally:
        db.close()

@app.get("/history/{thread_id}")
async def get_chat_history(thread_id: str):
    db = SessionLocal()
    try:
        messages = db.query(Message).filter(Message.thread_id == thread_id).order_by(Message.created_at.asc()).all()
        return [{"text": m.content, "isUser": m.role == "user"} for m in messages]
    finally:
        db.close()

@app.delete("/chat/{thread_id}")
async def delete_chat(thread_id: str):
    db = SessionLocal()
    try:
        db.query(Message).filter(Message.thread_id == thread_id).delete()
        db.commit()
        return {"status": "success"}
    finally:
        db.close()

if __name__ == "__main__":
    uvicorn.run("backend:app", host="0.0.0.0", port=8000, reload=True)
