from fastapi import FastAPI, HTTPException, Depends, Header, File, UploadFile, Form
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPBearer
from pydantic import BaseModel, EmailStr
from typing import Optional, List
import firebase_admin
from firebase_admin import credentials, firestore, auth
import random
import string
import datetime
import json
import os
import requests
from typing import Dict, List
import uuid
from dotenv import load_dotenv
from fastapi import UploadFile
import base64
import PyPDF2
from PIL import Image
import io

# Load environment variables
load_dotenv()

# Initialize Firebase Admin SDK
if not firebase_admin._apps:
    try:
        # Resolve service account path relative to this file for stable local dev
        service_account_path = os.path.join(os.path.dirname(__file__), "serviceAccountKey.json")

        # Try service account key first (development)
        if os.path.exists(service_account_path):
            cred = credentials.Certificate(service_account_path)
            print("✅ Using service account key")
        else:
            # Fallback to application default credentials (production)
            cred = credentials.ApplicationDefault()
            print("✅ Using application default credentials")
        
        firebase_admin.initialize_app(cred)
        print("✅ Firebase Admin SDK initialized")
    except Exception as e:
        print(f"❌ Firebase initialization failed: {e}")
        raise

db = firestore.client()
app = FastAPI(title="Classroom API", version="1.0.0")

# CORS middleware for frontend integration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure this properly for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Reserved for future auth middleware
# security = HTTPBearer()

# -------------------------------
# Pydantic Models
# -------------------------------

# Auth Models
class SignupRequest(BaseModel):
    email: EmailStr
    password: str
    full_name: str
    university: str

class LoginRequest(BaseModel):
    email: EmailStr
    password: str

class GoogleAuthRequest(BaseModel):
    id_token: str

class AuthResponse(BaseModel):
    user_id: str
    email: str
    full_name: str
    token: str

class UserProfile(BaseModel):
    user_id: str
    email: EmailStr
    full_name: str
    university: Optional[str] = None
    state: Optional[str] = None
    role: Optional[str] = None  # "student" | "instructor"

class ProfileUpdateRequest(BaseModel):
    university: Optional[str] = None
    state: Optional[str] = None
    role: Optional[str] = None

# Class Models
class JoinClassRequest(BaseModel):
    class_code: str

class ClassResponse(BaseModel):
    class_id: str
    name: str
    code: str
    created_by: str
    created_at: str
    join_mode: str
    visibility: str

class CreatePostRequest(BaseModel):
    title: str
    content: str
    post_type: str  # "question", "announcement", "discussion", etc.
    tags: List[str] = []
    files: List[str] = []  # File URLs/paths

class PostResponse(BaseModel):
    post_id: str
    title: str
    content: str
    post_type: str
    tags: List[str]
    author_id: str
    author_name: str
    created_at: str
    files: List[str]

class VoteRequest(BaseModel):
    value: int  # -1, 0, or 1

class CreateCommentRequest(BaseModel):
    content: str

class AIStudyRequest(BaseModel):
    message: str
    conversation_id: Optional[str] = None
    class_context: Optional[str] = None  # Can include class name, recent posts, etc.

class AIStudyResponse(BaseModel):
    response: str
    conversation_id: str
    timestamp: str

class ConversationHistory(BaseModel):
    conversation_id: str
    messages: List[Dict[str, str]]
    class_id: Optional[str] = None
    user_id: str
    created_at: str
    last_updated: str

class AIStudyWithFilesRequest(BaseModel):
    message: str
    conversation_id: Optional[str] = None
    class_context: Optional[str] = None
    file_types: List[str] = []  # Track what types of files were uploaded


class NoteSummaryRequest(BaseModel):
    title: Optional[str] = None
    class_id: str  # Now required

class NoteSummary(BaseModel):
    summary_id: str
    title: str
    key_concepts: List[str]
    main_points: List[str]
    study_tips: List[str]
    questions_for_review: List[str]
    difficulty_level: str  # "beginner", "intermediate", "advanced"
    estimated_study_time: str  # "30 minutes", "1 hour", etc.
    created_at: str
    file_sources: List[str]  # Original filenames
    class_id: Optional[str] = None
    user_id: str

class SummaryResponse(BaseModel):
    summary: NoteSummary
    raw_content_preview: str  # First 200 chars of original content

# Simple note models for user-written notes
class Note(BaseModel):
    note_id: str
    title: str
    content: str
    class_id: Optional[str] = None
    user_id: str
    created_at: str
    updated_at: str

class CreateNoteRequest(BaseModel):
    title: str
    content: str
    class_id: Optional[str] = None
    linked_summary_id: Optional[str] = None  # Add this field

class UpdateNoteRequest(BaseModel):
    title: Optional[str] = None
    content: Optional[str] = None

class SummarizeNotesRequest(BaseModel):
    note_ids: List[str]
    title: Optional[str] = None
    class_id: str

# -------------------------------
# Auth Dependencies
# -------------------------------
async def get_current_user(authorization: Optional[str] = Header(None)):
    """Extract and verify Firebase ID token from Authorization header and normalize uid."""
    if not authorization or not authorization.startswith('Bearer '):
        raise HTTPException(status_code=401, detail="Authentication required")
    
    token = authorization.split('Bearer ')[1]
    try:
        decoded_token = auth.verify_id_token(token)
        # Normalize UID: accept common token fields and ensure 'uid' exists for downstream code.
        uid = decoded_token.get('uid') or decoded_token.get('user_id') or decoded_token.get('sub')
        if not uid:
            raise Exception("UID missing in token")
        normalized = dict(decoded_token)
        normalized['uid'] = uid
        # Ensure common convenience fields exist
        if 'email' not in normalized and decoded_token.get('email'):
            normalized['email'] = decoded_token.get('email')
        if 'name' not in normalized and decoded_token.get('name'):
            normalized['name'] = decoded_token.get('name')
        return normalized
    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Invalid authentication token: {str(e)}")

# Mock auth for development/testing
async def mock_get_current_user():
    """Mock user for testing - replace with real auth in production"""
    return {
        'uid': 'test_user_id',
        'email': 'test@example.com',
        'name': 'Test User'
    }

# -------------------------------
# Utility Functions
# -------------------------------
def generate_class_code(length: int = 6) -> str:
    """Generate a class join code like 'ABC123'"""
    return "".join(random.choices(string.ascii_uppercase + string.digits, k=length))

def serialize_datetime(obj):
    """Convert datetime objects to ISO string for JSON serialization"""
    if isinstance(obj, datetime.datetime):
        return obj.isoformat()
    return obj

def get_ai_response(conversation_history: List[Dict], api_key: str, class_context: str = None) -> str:
    """Get AI response from OpenAI API with classroom context"""
    
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json"
    }
    
    # Enhance system prompt with class context if available
    system_message = conversation_history[0].copy()
    if class_context:
        system_message["content"] += f"\n\nClass Context: {class_context}"
    
    # Update the conversation with enhanced context
    enhanced_history = [system_message] + conversation_history[1:]
    
    data = {
        "model": "gpt-3.5-turbo",
        "messages": enhanced_history,
        "max_tokens": 300,
        "temperature": 0.7
    }
    
    try:
        response = requests.post(OPENAI_API_URL, headers=headers, json=data)
        response.raise_for_status()
        result = response.json()
        return result["choices"][0]["message"]["content"]
    except requests.exceptions.RequestException as e:
        raise HTTPException(status_code=500, detail=f"AI service error: {str(e)}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"AI processing error: {str(e)}")

def get_class_context(class_id: str, db) -> str:
    """Get recent class context for AI conversations"""
    try:
        # Get class info
        class_doc = db.collection("classes").document(class_id).get()
        if not class_doc.exists:
            return ""
        
        class_data = class_doc.to_dict()
        class_name = class_data.get("name", "")
        
        # Get recent posts for context (last 3 posts)
        recent_posts = (db.collection("classes").document(class_id)
                       .collection("posts")
                       .order_by("createdAt", direction=firestore.Query.DESCENDING)
                       .limit(3)
                       .stream())
        
        context = f"Class: {class_name}\n"
        context += "Recent discussion topics:\n"
        
        for post in recent_posts:
            post_data = post.to_dict()
            context += f"- {post_data.get('title', 'Untitled')}: {post_data.get('post_type', 'discussion')}\n"
        
        return context
    except Exception:
        return ""
    
def get_ai_response_with_files(conversation_history: List[Dict], api_key: str, 
                               files_content: List[Dict] = None, class_context: str = None) -> str:
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json"
    }
    
    # Enhance system prompt for file analysis
    system_message = conversation_history[0].copy()
    if files_content:
        system_message["content"] += "\n\nYou can analyze uploaded files (PDFs and images). When files are provided, analyze their content and help the student understand the material through guiding questions."
    
    if class_context:
        system_message["content"] += f"\n\nClass Context: {class_context}"
    
    enhanced_history = [system_message] + conversation_history[1:]
    
    # Add file content to the last user message if files were provided
    if files_content and enhanced_history:
        last_message = enhanced_history[-1]
        if last_message.get("role") == "user":
            # For OpenAI GPT-4 Vision API
            if any(f["type"] == "image" for f in files_content):
                last_message["content"] = [
                    {"type": "text", "text": last_message["content"]}
                ] + files_content
            else:
                # For text content from PDFs
                text_content = "\n\n".join([f["content"] for f in files_content if f["type"] == "text"])
                last_message["content"] += f"\n\nFile content:\n{text_content}"
    
    data = {
        "model": "gpt-4-vision-preview" if any(f.get("type") == "image" for f in files_content or []) else "gpt-3.5-turbo",
        "messages": enhanced_history,
        "max_tokens": 500,
        "temperature": 0.7
    }
    
    response = requests.post("https://api.openai.com/v1/chat/completions", headers=headers, json=data)
    response.raise_for_status()
    result = response.json()
    return result["choices"][0]["message"]["content"]

# File processing functions
def extract_pdf_text(pdf_file: UploadFile) -> str:
    pdf_reader = PyPDF2.PdfReader(pdf_file.file)
    text = ""
    for page in pdf_reader.pages:
        text += page.extract_text() + "\n"
    return text

def process_image(image_file: UploadFile) -> str:
    image_bytes = image_file.file.read()
    base64_image = base64.b64encode(image_bytes).decode('utf-8')
    return f"data:image/{image_file.filename.split('.')[-1]};base64,{base64_image}"

def extract_text_from_image(image_file: UploadFile, api_key: str) -> str:
    """Extract text content from image using OpenAI Vision API"""
    try:
        # Convert image to base64
        image_bytes = image_file.file.read()
        base64_image = base64.b64encode(image_bytes).decode('utf-8')

        # Determine image format
        file_extension = image_file.filename.split('.')[-1].lower()
        mime_type = f"image/{file_extension if file_extension in ['png', 'jpeg', 'jpg'] else 'jpeg'}"

        # Use OpenAI Vision API to extract text
        headers = {
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json"
        }

        data = {
            "model": "gpt-4o",  # gpt-4o has vision capabilities and is faster/cheaper than gpt-4-vision-preview
            "messages": [
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "text",
                            "text": "Please extract ALL text content from this image. If it's a class note, lecture slide, or study material, transcribe everything you see including headings, bullet points, definitions, examples, and any other text. Preserve the structure and formatting as much as possible. Return ONLY the extracted text content, nothing else."
                        },
                        {
                            "type": "image_url",
                            "image_url": {
                                "url": f"data:{mime_type};base64,{base64_image}"
                            }
                        }
                    ]
                }
            ],
            "max_tokens": 2000
        }

        response = requests.post(OPENAI_API_URL, headers=headers, json=data)
        response.raise_for_status()
        result = response.json()

        extracted_text = result["choices"][0]["message"]["content"].strip()
        return extracted_text

    except Exception as e:
        # Fallback to placeholder if vision API fails
        return f"[Image file: {image_file.filename} - text extraction failed: {str(e)}]"

def get_structured_summary(file_content: str, api_key: str, user_title: str = None) -> dict:
    """Get structured JSON summary from OpenAI"""
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json"
    }
    
    user_message = f"Analyze and summarize this content:\n\n{file_content[:3000]}"  # Limit content length
    if user_title:
        user_message = f"Title: {user_title}\n\n{user_message}"
    
    data = {
        "model": "gpt-3.5-turbo",
        "messages": [
            {"role": "system", "content": SUMMARY_SYSTEM_PROMPT},
            {"role": "user", "content": user_message}
        ],
        "max_tokens": 800,
        "temperature": 0.3  # Lower temperature for more consistent JSON
    }
    
    try:
        response = requests.post(OPENAI_API_URL, headers=headers, json=data)
        response.raise_for_status()
        result = response.json()
        
        ai_response = result["choices"][0]["message"]["content"].strip()
        
        # Parse JSON response
        try:
            summary_data = json.loads(ai_response)
            return summary_data
        except json.JSONDecodeError as e:
            # Fallback: try to extract JSON from response if AI added extra text
            import re
            json_match = re.search(r'\{.*\}', ai_response, re.DOTALL)
            if json_match:
                return json.loads(json_match.group())
            else:
                raise HTTPException(status_code=500, detail=f"AI returned invalid JSON: {str(e)}")
                
    except requests.exceptions.RequestException as e:
        raise HTTPException(status_code=500, detail=f"AI service error: {str(e)}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Summary processing error: {str(e)}")



# -------------------------------
# AUTH ENDPOINTS
# -------------------------------
@app.post("/api/v1/auth/signup", response_model=AuthResponse)
async def signup(request: SignupRequest):
    """Register new user account"""
    try:
        # Create Firebase user
        user_record = auth.create_user(
            email=request.email,
            password=request.password,
            display_name=request.full_name
        )
        
        # Create user profile in Firestore
        user_data = {
            "email": request.email,
            "full_name": request.full_name,
            "university": request.university,
            "state": None,
            "role": None,
            "created_at": datetime.datetime.utcnow(),
            "karma": 0
        }
        db.collection("users").document(user_record.uid).set(user_data)
        
        # Generate custom token for immediate login
        custom_token = auth.create_custom_token(user_record.uid)
        
        return AuthResponse(
            user_id=user_record.uid,
            email=request.email,
            full_name=request.full_name,
            token=custom_token.decode('utf-8')
        )
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Registration failed: {str(e)}")

@app.post("/api/v1/auth/login")
async def login(request: LoginRequest):
    """Authenticate user login with password verification"""
    try:
        firebase_api_key = os.getenv("FIREBASE_API_KEY")
        
        # Debug: Print whether API key exists (don't print the actual key!)
        print(f"🔑 Firebase API Key exists: {firebase_api_key is not None}")
        print(f"🔑 Firebase API Key length: {len(firebase_api_key) if firebase_api_key else 0}")
        
        if not firebase_api_key:
            raise HTTPException(
                status_code=500, 
                detail="Firebase API key not configured. Check your .env file for FIREBASE_API_KEY"
            )

        # Use Firebase Auth REST API to verify password
        sign_in_url = f"https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key={firebase_api_key}"
        
        print(f"🔐 Attempting login for: {request.email}")
        
        try:
            sign_in_response = requests.post(
                sign_in_url,
                json={
                    "email": request.email,
                    "password": request.password,
                    "returnSecureToken": True
                },
                headers={"Content-Type": "application/json"},
                timeout=10
            )
        except requests.exceptions.Timeout:
            raise HTTPException(status_code=504, detail="Firebase authentication timed out")
        except requests.exceptions.RequestException as e:
            print(f"❌ Network error: {str(e)}")
            raise HTTPException(status_code=500, detail=f"Network error connecting to Firebase: {str(e)}")

        print(f"📡 Firebase response status: {sign_in_response.status_code}")
        
        if sign_in_response.status_code != 200:
            error_data = sign_in_response.json()
            error_message = error_data.get("error", {}).get("message", "UNKNOWN_ERROR")
            
            print(f"❌ Firebase error: {error_message}")
            
            # Provide user-friendly error messages
            if "INVALID_PASSWORD" in error_message:
                raise HTTPException(status_code=401, detail="Invalid password")
            elif "EMAIL_NOT_FOUND" in error_message:
                raise HTTPException(status_code=401, detail="No account found with this email")
            elif "USER_DISABLED" in error_message:
                raise HTTPException(status_code=403, detail="This account has been disabled")
            elif "TOO_MANY_ATTEMPTS_TRY_LATER" in error_message:
                raise HTTPException(status_code=429, detail="Too many failed attempts. Try again later")
            elif "INVALID_LOGIN_CREDENTIALS" in error_message:
                raise HTTPException(status_code=401, detail="Invalid email or password")
            else:
                raise HTTPException(status_code=401, detail=f"Authentication failed: {error_message}")

        token_data = sign_in_response.json()
        id_token = token_data.get("idToken")
        user_id = token_data.get("localId")

        if not id_token or not user_id:
            print("❌ Token or user_id missing from Firebase response")
            raise HTTPException(status_code=500, detail="Authentication response incomplete")

        print(f"✅ Login successful for user: {user_id}")

        # Get user profile
        user_doc = db.collection("users").document(user_id).get()
        user_data = user_doc.to_dict() if user_doc.exists else {}

        return {
            "user_id": user_id,
            "email": request.email,
            "full_name": user_data.get("full_name", ""),
            "token": id_token
        }
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ Unexpected error in login: {str(e)}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Login failed: {str(e)}")

@app.post("/api/v1/auth/google")
async def google_auth(request: GoogleAuthRequest):
    """Google OAuth authentication"""
    try:
        decoded_token = auth.verify_id_token(request.id_token)
        uid = decoded_token['uid']
        
        # Check if user exists, create if not
        user_doc = db.collection("users").document(uid).get()
        if not user_doc.exists:
            user_data = {
                "email": decoded_token.get('email', ''),
                "full_name": decoded_token.get('name', ''),
                "university": "",  # User can update this later
                "created_at": datetime.datetime.utcnow(),
                "karma": 0
            }
            db.collection("users").document(uid).set(user_data)
        else:
            user_data = user_doc.to_dict()
        
        return AuthResponse(
            user_id=uid,
            email=decoded_token.get('email', ''),
            full_name=user_data.get('full_name', ''),
            token=request.id_token
        )
    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Google authentication failed: {str(e)}")

@app.post("/api/v1/auth/signout")
async def signout(current_user: dict = Depends(get_current_user)):
    """Sign out current user"""
    # In Firebase, sign out is typically handled on the frontend
    # Backend can revoke tokens if needed
    try:
        auth.revoke_refresh_tokens(current_user['uid'])
        return {"message": "Successfully signed out"}
    except Exception as e:
        return {"message": "Signed out (token revocation failed)"}

# -------------------------------
# USER PROFILE ENDPOINTS
# -------------------------------

@app.get("/api/v1/users/me", response_model=UserProfile)
async def get_me(email: Optional[str] = None, current_user: dict = Depends(get_current_user)):
    """Get current user's profile.
    - If email is provided, resolve via Firestore users.email == email; if missing, try Firebase Auth to get uid and upsert a minimal profile.
    - If no email is provided, use current_user.uid.
    """
    try:
        if email:
            # First, try Firestore by email
            users_q = list(db.collection("users").where("email", "==", email).limit(1).stream())
            if users_q:
                doc = users_q[0]
                data = doc.to_dict()
                return UserProfile(
                    user_id=doc.id,
                    email=data.get("email", ""),
                    full_name=data.get("full_name", ""),
                    university=data.get("university"),
                    state=data.get("state"),
                    role=data.get("role"),
                )

            # Not found in Firestore → try Firebase Auth and upsert
            try:
                user_record = auth.get_user_by_email(email)
                uid = user_record.uid
            except Exception:
                raise HTTPException(status_code=404, detail="User not found")

            user_doc_ref = db.collection("users").document(uid)
            user_doc = user_doc_ref.get()
            if not user_doc.exists:
                user_doc_ref.set({
                    "email": email,
                    "full_name": getattr(user_record, 'display_name', "") or "",
                    "university": None,
                    "state": None,
                    "role": None,
                    "created_at": datetime.datetime.utcnow(),
                    "karma": 0,
                })
                data = user_doc_ref.get().to_dict()
            else:
                data = user_doc.to_dict()

            return UserProfile(
                user_id=uid,
                email=data.get("email", ""),
                full_name=data.get("full_name", ""),
                university=data.get("university"),
                state=data.get("state"),
                role=data.get("role"),
            )

        # No email param: use current_user
        uid = current_user.get('uid')
        user_doc = db.collection("users").document(uid).get()
        if not user_doc.exists:
            raise HTTPException(status_code=404, detail="User profile not found")
        data = user_doc.to_dict()
        return UserProfile(
            user_id=uid,
            email=data.get("email", ""),
            full_name=data.get("full_name", ""),
            university=data.get("university"),
            state=data.get("state"),
            role=data.get("role"),
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to load profile: {str(e)}")

@app.put("/api/v1/users/me")
async def update_me(payload: ProfileUpdateRequest, email: Optional[str] = None, current_user: dict = Depends(get_current_user)):
    """Update current user's profile. If email is provided, resolve via Firebase Auth and upsert by uid."""
    try:
        update_data = {k: v for k, v in payload.model_dump().items() if v is not None}
        if not update_data:
            return {"message": "No changes"}

        if email:
            try:
                user_record = auth.get_user_by_email(email)
                uid = user_record.uid
            except Exception:
                raise HTTPException(status_code=404, detail="User not found")
            db.collection("users").document(uid).set({
                "email": email,
                **update_data
            }, merge=True)
        else:
            uid = current_user.get('uid')
            db.collection("users").document(uid).set(update_data, merge=True)
        return {"message": "Profile updated"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to update profile: {str(e)}")

# -------------------------------
# AI STUDY BOT ENDPOINTS
# -------------------------------

OPENAI_API_URL = "https://api.openai.com/v1/chat/completions"
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "your-openai-api-key-here")
STUDY_BUDDY_SYSTEM_PROMPT = """You are an AI Study Buddy for a classroom discussion platform. Your role is to help students learn by:

1. Asking guiding questions instead of giving direct answers
2. Encouraging critical thinking and exploration
3. Relating topics to the class context when provided
4. Being supportive and encouraging
5. Suggesting study strategies and learning approaches

When a student asks a question:
- Ask a guiding question back to help them think through the problem
- Break down complex topics into smaller, manageable parts
- Encourage them to connect ideas to what they already know
- Suggest resources or study methods when appropriate

Keep responses concise but helpful. Always aim to facilitate learning rather than just providing answers."""

SUMMARY_SYSTEM_PROMPT = """You are an AI that creates structured study summaries. When given document content, you must respond with ONLY a valid JSON object in this exact format:

{
    "key_concepts": ["concept1", "concept2", "concept3"],
    "main_points": ["point1", "point2", "point3"],
    "study_tips": ["tip1", "tip2", "tip3"],
    "questions_for_review": ["question1?", "question2?", "question3?"],
    "difficulty_level": "beginner|intermediate|advanced",
    "estimated_study_time": "X minutes|X hours",
    "title": "Short descriptive title based on the main topic"
}

Rules:
- Always return valid JSON only, no other text
- Include 3-7 items in each array
- Make study tips actionable and specific
- Make review questions thought-provoking
- Base difficulty on content complexity
- Estimate realistic study time
- Generate a clear, specific title that captures the main topic or lesson (e.g., "Introduction to Object-Oriented Programming", "Chemical Reactions and Equilibrium", "The French Revolution Overview")"""
@app.post("/api/v1/ai-study-buddy", response_model=AIStudyResponse)
async def chat_with_study_buddy(
    request: AIStudyRequest,
    current_user: dict = Depends(get_current_user)
):
    """Chat with AI Study Buddy"""
    try:
        if not OPENAI_API_KEY or OPENAI_API_KEY == "your-openai-api-key-here":
            raise HTTPException(status_code=503, detail="AI service not configured")
        
        # Generate or use existing conversation ID
        conversation_id = request.conversation_id or str(uuid.uuid4())
        
        # Get or create conversation history
        conv_doc_ref = db.collection("ai_conversations").document(conversation_id)
        conv_doc = conv_doc_ref.get()
        
        if conv_doc.exists:
            conv_data = conv_doc.to_dict()
            conversation_history = conv_data.get("messages", [])
        else:
            # Initialize new conversation with system prompt
            conversation_history = [
                {"role": "system", "content": STUDY_BUDDY_SYSTEM_PROMPT}
            ]
        
        # Add user message to history
        conversation_history.append({"role": "user", "content": request.message})
        
        # Get class context if provided
        class_context = ""
        if request.class_context:
            class_context = get_class_context(request.class_context, db)
        
        # Get AI response
        ai_response = get_ai_response(conversation_history, OPENAI_API_KEY, class_context)
        
        # Add AI response to history
        conversation_history.append({"role": "assistant", "content": ai_response})
        
        # Save conversation to Firestore
        conv_data = {
            "conversation_id": conversation_id,
            "messages": conversation_history,
            "class_id": request.class_context,
            "user_id": current_user['uid'],
            "created_at": conv_doc.get("created_at") if conv_doc.exists else datetime.datetime.utcnow(),
            "last_updated": datetime.datetime.utcnow()
        }
        conv_doc_ref.set(conv_data)
        
        return AIStudyResponse(
            response=ai_response,
            conversation_id=conversation_id,
            timestamp=datetime.datetime.utcnow().isoformat()
        )
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Study buddy error: {str(e)}")

@app.get("/api/v1/ai-study-buddy/conversations")
async def get_study_buddy_conversations(
    current_user: dict = Depends(get_current_user)
):
    """Get user's AI study buddy conversation history"""
    try:
        conversations = (db.collection("ai_conversations")
                        .where("user_id", "==", current_user['uid'])
                        .order_by("last_updated", direction=firestore.Query.DESCENDING)
                        .limit(10)
                        .stream())
        
        conversation_list = []
        for conv in conversations:
            conv_data = conv.to_dict()
            # Get the first user message as preview
            first_message = ""
            for msg in conv_data.get("messages", []):
                if msg.get("role") == "user":
                    first_message = msg.get("content", "")[:100] + "..."
                    break
            
            conversation_list.append({
                "conversation_id": conv_data.get("conversation_id"),
                "preview": first_message,
                "class_id": conv_data.get("class_id"),
                "last_updated": serialize_datetime(conv_data.get("last_updated")),
                "message_count": len([m for m in conv_data.get("messages", []) if m.get("role") != "system"])
            })
        
        return {"conversations": conversation_list}
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get conversations: {str(e)}")

@app.get("/api/v1/ai-study-buddy/conversations/{conversation_id}")
async def get_conversation_details(
    conversation_id: str,
    current_user: dict = Depends(get_current_user)
):
    """Get specific AI study buddy conversation"""
    try:
        conv_doc = db.collection("ai_conversations").document(conversation_id).get()
        if not conv_doc.exists:
            raise HTTPException(status_code=404, detail="Conversation not found")
        
        conv_data = conv_doc.to_dict()
        
        # Verify user owns this conversation
        if conv_data.get("user_id") != current_user['uid']:
            raise HTTPException(status_code=403, detail="Access denied")
        
        # Format messages for response (exclude system message)
        formatted_messages = []
        for msg in conv_data.get("messages", []):
            if msg.get("role") != "system":
                formatted_messages.append({
                    "role": msg.get("role"),
                    "content": msg.get("content"),
                    "timestamp": serialize_datetime(conv_data.get("last_updated"))
                })
        
        return {
            "conversation_id": conversation_id,
            "messages": formatted_messages,
            "class_id": conv_data.get("class_id"),
            "created_at": serialize_datetime(conv_data.get("created_at")),
            "last_updated": serialize_datetime(conv_data.get("last_updated"))
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get conversation: {str(e)}")

@app.post("/api/v1/classes/{class_id}/ai-study-buddy")
async def class_specific_study_buddy(
    class_id: str,
    request: AIStudyRequest,
    current_user: dict = Depends(get_current_user)
):
    """Chat with AI Study Buddy in context of specific class"""
    try:
        # Verify user is member of class
        member_doc = db.collection("classMembers").document(f"{class_id}_{current_user['uid']}").get()
        if not member_doc.exists:
            raise HTTPException(status_code=403, detail="Not a member of this class")
        
        # Set class context and call main study buddy endpoint
        request.class_context = class_id
        return await chat_with_study_buddy(request, current_user)
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Class study buddy error: {str(e)}")

# Add this endpoint to integrate AI suggestions with posts
@app.post("/api/v1/classes/{class_id}/posts/{post_id}/ai-help")
async def get_ai_help_for_post(
    class_id: str,
    post_id: str,
    current_user: dict = Depends(get_current_user)
):
    """Get AI study buddy help for a specific post"""
    try:
        # Verify user is member of class
        member_doc = db.collection("classMembers").document(f"{class_id}_{current_user['uid']}").get()
        if not member_doc.exists:
            raise HTTPException(status_code=403, detail="Not a member of this class")
        
        # Get post content
        post_doc = (db.collection("classes").document(class_id)
                   .collection("posts").document(post_id).get())
        if not post_doc.exists:
            raise HTTPException(status_code=404, detail="Post not found")
        
        post_data = post_doc.to_dict()
        
        # Create AI request based on post content
        ai_request = AIStudyRequest(
            message=f"I'm looking at this post: '{post_data.get('title')}' - {post_data.get('content')[:200]}... Can you help me understand this better?",
            class_context=class_id
        )
        
        return await chat_with_study_buddy(ai_request, current_user)
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"AI post help error: {str(e)}")

# -------------------------------
# CLASS ENDPOINTS
# -------------------------------
class CreateClassRequest(BaseModel):
    name: str
    visibility: Optional[str] = "private"  # private|public
    join_mode: Optional[str] = "code"      # code|open

# --- Assignments & Roster models ---
class CreateAssignmentRequest(BaseModel):
    title: str
    description: Optional[str] = None
    due_date: Optional[str] = None  # ISO8601 string

class SetGradeRequest(BaseModel):
    assignment_id: str
    grade: float


@app.post("/api/v1/classes")
async def create_class(request: CreateClassRequest, email: Optional[str] = None, current_user: dict = Depends(get_current_user)):
    """Create a class and add the creator as instructor.
    In dev, allow ?email=... to resolve the creating user by Firebase Auth.
    """
    try:
        # Resolve creator uid
        if email:
            user_record = auth.get_user_by_email(email)
            creator_uid = user_record.uid
        else:
            creator_uid = current_user.get('uid')

        class_ref = db.collection("classes").document()
        class_id = class_ref.id
        code = generate_class_code()
        class_doc = {
            "name": request.name,
            "code": code,
            "createdBy": creator_uid,
            "createdAt": datetime.datetime.utcnow(),
            "joinMode": request.join_mode,
            "visibility": request.visibility,
        }
        class_ref.set(class_doc)

        # Add creator as instructor member
        member_doc = {
            "classId": class_id,
            "userId": creator_uid,
            "role": "instructor",
            "joinedAt": datetime.datetime.utcnow()
        }
        db.collection("classMembers").document(f"{class_id}_{creator_uid}").set(member_doc)

        return {
            "class_id": class_id,
            "name": request.name,
            "code": code,
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to create class: {str(e)}")
@app.get("/api/v1/classes")
async def get_user_classes(email: Optional[str] = None, current_user: dict = Depends(get_current_user)):
    """Get user's enrolled classes. In dev, allow ?email=... to resolve uid via Firebase Auth."""
    try:
        # Resolve uid from email if provided (dev convenience), else use current user
        if email:
            try:
                user_record = auth.get_user_by_email(email)
                resolved_uid = user_record.uid
            except Exception:
                raise HTTPException(status_code=404, detail="User not found")
        else:
            resolved_uid = current_user['uid']

        # Get user's class memberships
        memberships = db.collection("classMembers").where("userId", "==", resolved_uid).stream()
        
        classes = []
        for membership in memberships:
            member_data = membership.to_dict()
            class_id = member_data.get("classId")
            
            # Get class details
            class_doc = db.collection("classes").document(class_id).get()
            if class_doc.exists:
                class_data = class_doc.to_dict()
                classes.append({
                    "class_id": class_id,
                    "name": class_data.get("name"),
                    "code": class_data.get("code"),
                    "role": member_data.get("role"),
                    "joined_at": serialize_datetime(member_data.get("joinedAt"))
                })
        
        return {"classes": classes}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to fetch classes: {str(e)}")

@app.get("/api/v1/classes/search")
async def search_classes(
    name: Optional[str] = None,
    teacher: Optional[str] = None,
    limit: int = 20,
    current_user: dict = Depends(get_current_user)
):
    """Search for classes by name or teacher name"""
    try:
        if not name and not teacher:
            raise HTTPException(status_code=400, detail="Must provide at least one search parameter: name or teacher")

        # Start with all classes
        query = db.collection("classes")

        # Build query based on provided parameters
        # Note: Firestore doesn't support full-text search or case-insensitive queries natively,
        # so we'll do client-side filtering for more flexible matching
        classes = list(query.stream())

        results = []
        name_lower = name.lower() if name else None
        teacher_lower = teacher.lower() if teacher else None

        for class_doc in classes:
            class_data = class_doc.to_dict()
            class_name = (class_data.get("name") or "").lower()
            teacher_id = class_data.get("teacher_id")

            # Check name match
            name_match = not name_lower or name_lower in class_name

            # Check teacher match - need to get teacher's full name
            teacher_match = True
            if teacher_lower and teacher_id:
                try:
                    teacher_doc = db.collection("users").document(teacher_id).get()
                    if teacher_doc.exists:
                        teacher_data = teacher_doc.to_dict()
                        teacher_full_name = (teacher_data.get("full_name") or "").lower()
                        teacher_match = teacher_lower in teacher_full_name
                    else:
                        teacher_match = False
                except Exception:
                    teacher_match = False
            elif teacher_lower:
                teacher_match = False

            # Include if both conditions match
            if name_match and teacher_match:
                # Get teacher info for result
                teacher_info = {}
                if teacher_id:
                    try:
                        teacher_doc = db.collection("users").document(teacher_id).get()
                        if teacher_doc.exists:
                            teacher_data = teacher_doc.to_dict()
                            teacher_info = {
                                "teacher_id": teacher_id,
                                "teacher_name": teacher_data.get("full_name", "Unknown")
                            }
                    except Exception:
                        pass

                results.append({
                    "class_id": class_doc.id,
                    "name": class_data.get("name"),
                    "code": class_data.get("code"),
                    "created_at": serialize_datetime(class_data.get("createdAt")),
                    **teacher_info
                })

                # Apply limit
                if len(results) >= limit:
                    break

        return {"classes": results}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to search classes: {str(e)}")

@app.post("/api/v1/classes/join")
async def join_class_by_code(request: JoinClassRequest, email: Optional[str] = None, current_user: dict = Depends(get_current_user)):
    """Join class by code"""
    try:
        code = request.class_code.upper()
        
        # Find class by code
        classes_query = db.collection("classes").where("code", "==", code).limit(1)
        classes = list(classes_query.stream())
        
        if not classes:
            raise HTTPException(status_code=404, detail="Invalid class code")
        
        class_doc = classes[0]
        class_id = class_doc.id
        class_data = class_doc.to_dict()
        
        # Resolve user id
        if email:
            try:
                user_record = auth.get_user_by_email(email)
                uid = user_record.uid
            except Exception:
                raise HTTPException(status_code=404, detail="User not found")
        else:
            uid = current_user['uid']
        
        # Check if already a member
        member_doc = db.collection("classMembers").document(f"{class_id}_{uid}").get()
        if member_doc.exists:
            return {"message": "Already a member of this class", "class_id": class_id}
        
        # Add as student
        member_data = {
            "classId": class_id,
            "userId": uid,
            "role": "student",
            "joinedAt": datetime.datetime.utcnow()
        }
        db.collection("classMembers").document(f"{class_id}_{uid}").set(member_data)
        
        return {
            "message": "Successfully joined class",
            "class_id": class_id,
            "class_name": class_data.get("name")
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to join class: {str(e)}")

@app.get("/api/v1/classes/{class_id}")
async def get_class_details(class_id: str, limit: int = 20, offset: int = 0, 
                           current_user: dict = Depends(get_current_user)):
    """Get class details and posts"""
    try:
        # Verify user is member of class (student OR instructor) - this was also part of the issue
        member_doc = db.collection("classMembers").document(f"{class_id}_{current_user['uid']}").get()
        if not member_doc.exists:
            raise HTTPException(status_code=403, detail="Not a member of this class")
        
        user_role = member_doc.to_dict().get("role", "student")
        
        # Get class details
        class_doc = db.collection("classes").document(class_id).get()
        if not class_doc.exists:
            raise HTTPException(status_code=404, detail="Class not found")
        
        class_data = class_doc.to_dict()
        
        # Get posts with pagination
        posts_query = (db.collection("classes").document(class_id)
                      .collection("posts")
                      .order_by("createdAt", direction=firestore.Query.DESCENDING)
                      .limit(limit)
                      .offset(offset))
        
        posts = []
        for post_doc in posts_query.stream():
            post_data = post_doc.to_dict()
            
            # Get author info
            author_doc = db.collection("users").document(post_data.get("authorId", "")).get()
            author_data = author_doc.to_dict() if author_doc.exists else {}
            # Aggregate votes
            votes_col = (db.collection("classes").document(class_id)
                         .collection("posts").document(post_doc.id)
                         .collection("votes"))
            upvotes = len(list(votes_col.where("value", "==", 1).stream()))
            downvotes = len(list(votes_col.where("value", "==", -1).stream()))
            score = upvotes - downvotes
            my_vote_doc = votes_col.document(current_user['uid']).get()
            my_vote = my_vote_doc.to_dict().get("value") if my_vote_doc.exists else 0
            # Count comments
            comments_col = (db.collection("classes").document(class_id)
                            .collection("posts").document(post_doc.id)
                            .collection("comments"))
            comment_count = len(list(comments_col.stream()))
            
            posts.append({
                "post_id": post_doc.id,
                "title": post_data.get("title", ""),
                "content": post_data.get("content", ""),
                "post_type": post_data.get("post_type", "discussion"),
                "tags": post_data.get("tags", []),
                "author_id": post_data.get("authorId"),
                "author_name": author_data.get("full_name", "Unknown"),
                "created_at": serialize_datetime(post_data.get("createdAt")),
                "files": post_data.get("files", []),
                "score": score,
                "my_vote": my_vote,
                "comment_count": comment_count
            })
        
        return {
            "class": {
                "class_id": class_id,
                "name": class_data.get("name"),
                "code": class_data.get("code"),
                "created_by": class_data.get("createdBy"),
                "created_at": serialize_datetime(class_data.get("createdAt")),
                "join_mode": class_data.get("joinMode"),
                "visibility": class_data.get("visibility"),
                "user_role": user_role  # Add this so frontend knows user's role
            },
            "posts": posts,
            "pagination": {
                "limit": limit,
                "offset": offset,
                "has_more": len(posts) == limit
            }
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get class details: {str(e)}")

@app.delete("/api/v1/classes/{class_id}")
async def delete_class(class_id: str, email: Optional[str] = None, current_user: dict = Depends(get_current_user)):
    """Delete a class and related data (instructors only; creator can delete).
    In dev, allow ?email=... to resolve the actor via Firebase Auth.
    """
    try:
        # Resolve acting uid
        if email:
            try:
                user_record = auth.get_user_by_email(email)
                uid = user_record.uid
            except Exception:
                raise HTTPException(status_code=404, detail="User not found")
        else:
            uid = current_user.get('uid')

        # Verify class exists
        class_ref = db.collection("classes").document(class_id)
        class_doc = class_ref.get()
        if not class_doc.exists:
            raise HTTPException(status_code=404, detail="Class not found")
        class_data = class_doc.to_dict()

        # Verify user is instructor and creator
        creator_uid = class_data.get("createdBy")
        member_doc = db.collection("classMembers").document(f"{class_id}_{uid}").get()
        if not member_doc.exists or member_doc.to_dict().get("role") != "instructor" or uid != creator_uid:
            raise HTTPException(status_code=403, detail="Only the creating instructor can delete this class")

        # Best-effort delete subcollections
        def _delete_subcollection(parent_ref, sub_name):
            try:
                for doc in parent_ref.collection(sub_name).stream():
                    doc.reference.delete()
            except Exception:
                pass

        _delete_subcollection(class_ref, "posts")
        _delete_subcollection(class_ref, "assignments")
        _delete_subcollection(class_ref, "grades")

        # Delete memberships for this class
        try:
            for m in db.collection("classMembers").where("classId", "==", class_id).stream():
                m.reference.delete()
        except Exception:
            pass

        # Finally delete the class document
        class_ref.delete()

        return {"message": "Class deleted"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to delete class: {str(e)}")

@app.post("/api/v1/classes/{class_id}/posts")
async def create_post(class_id: str, request: CreatePostRequest, 
                     current_user: dict = Depends(get_current_user)):
    """Create new post in class"""
    try:
        # Verify user is member of class
        member_doc = db.collection("classMembers").document(f"{class_id}_{current_user['uid']}").get()
        if not member_doc.exists:
            raise HTTPException(status_code=403, detail="Not a member of this class")
        
        # Create post
        post_ref = (db.collection("classes").document(class_id)
                   .collection("posts").document())
        
        post_data = {
            "title": request.title,
            "content": request.content,
            "post_type": request.post_type,
            "tags": request.tags,
            "files": request.files,
            "authorId": current_user['uid'],
            "createdAt": datetime.datetime.utcnow(),
            "isPublic": True
        }
        post_ref.set(post_data)
        
        return {
            "message": "Post created successfully",
            "post_id": post_ref.id
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to create post: {str(e)}")

@app.post("/api/v1/classes/{class_id}/posts/{post_id}/vote")
async def vote_on_post(class_id: str, post_id: str, request: VoteRequest, current_user: dict = Depends(get_current_user)):
    """Upvote/downvote/unvote a post. value in {-1, 0, 1}."""
    try:
        if request.value not in (-1, 0, 1):
            raise HTTPException(status_code=400, detail="Invalid vote value")

        # Membership check
        member_doc = db.collection("classMembers").document(f"{class_id}_{current_user['uid']}").get()
        if not member_doc.exists:
            raise HTTPException(status_code=403, detail="Not a member of this class")

        post_ref = (db.collection("classes").document(class_id)
                    .collection("posts").document(post_id))
        if not post_ref.get().exists:
            raise HTTPException(status_code=404, detail="Post not found")

        vote_ref = post_ref.collection("votes").document(current_user['uid'])
        if request.value == 0:
            vote_ref.delete()
        else:
            vote_ref.set({
                "userId": current_user['uid'],
                "value": request.value,
                "updatedAt": datetime.datetime.utcnow(),
            })

        # Recompute score and my vote
        votes_col = post_ref.collection("votes")
        upvotes = len(list(votes_col.where("value", "==", 1).stream()))
        downvotes = len(list(votes_col.where("value", "==", -1).stream()))
        score = upvotes - downvotes
        my_vote_doc = vote_ref.get()
        my_vote = my_vote_doc.to_dict().get("value") if my_vote_doc.exists else 0

        return {"score": score, "my_vote": my_vote}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to vote: {str(e)}")

@app.get("/api/v1/classes/{class_id}/posts/{post_id}/comments")
async def list_post_comments(class_id: str, post_id: str, limit: int = 50, current_user: dict = Depends(get_current_user)):
    """List comments for a post."""
    try:
        member_doc = db.collection("classMembers").document(f"{class_id}_{current_user['uid']}").get()
        if not member_doc.exists:
            raise HTTPException(status_code=403, detail="Not a member of this class")

        post_ref = (db.collection("classes").document(class_id)
                    .collection("posts").document(post_id))
        if not post_ref.get().exists:
            raise HTTPException(status_code=404, detail="Post not found")

        q = (post_ref.collection("comments")
             .order_by("createdAt", direction=firestore.Query.DESCENDING)
             .limit(limit))

        results = []
        for cdoc in q.stream():
            c = cdoc.to_dict()
            user_doc = db.collection("users").document(c.get("authorId", "")).get()
            u = user_doc.to_dict() if user_doc.exists else {}
            results.append({
                "comment_id": cdoc.id,
                "content": c.get("content", ""),
                "author_id": c.get("authorId"),
                "author_name": u.get("full_name", "Unknown"),
                "created_at": serialize_datetime(c.get("createdAt")),
            })

        return {"comments": results}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to list comments: {str(e)}")

@app.post("/api/v1/classes/{class_id}/posts/{post_id}/comments")
async def add_post_comment(class_id: str, post_id: str, request: CreateCommentRequest, current_user: dict = Depends(get_current_user)):
    """Add a comment to a post."""
    try:
        if not request.content or not request.content.strip():
            raise HTTPException(status_code=400, detail="Content is required")

        member_doc = db.collection("classMembers").document(f"{class_id}_{current_user['uid']}").get()
        if not member_doc.exists:
            raise HTTPException(status_code=403, detail="Not a member of this class")

        post_ref = (db.collection("classes").document(class_id)
                    .collection("posts").document(post_id))
        if not post_ref.get().exists:
            raise HTTPException(status_code=404, detail="Post not found")

        c_ref = post_ref.collection("comments").document()
        c_ref.set({
            "content": request.content.strip(),
            "authorId": current_user['uid'],
            "createdAt": datetime.datetime.utcnow(),
        })

        return {"message": "Comment added", "comment_id": c_ref.id}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to add comment: {str(e)}")

@app.post("/api/v1/classes/{class_id}/assignments")
async def create_assignment(class_id: str, request: CreateAssignmentRequest, current_user: dict = Depends(get_current_user)):
    """Create an assignment (instructors only)."""
    try:
        # Verify membership and role
        member_doc = db.collection("classMembers").document(f"{class_id}_{current_user['uid']}").get()
        if not member_doc.exists:
            raise HTTPException(status_code=403, detail="Not a member of this class")
        role = member_doc.to_dict().get("role")
        if role != "instructor":
            raise HTTPException(status_code=403, detail="Only instructors can create assignments")

        # Create assignment under class
        asg_ref = (db.collection("classes").document(class_id)
                   .collection("assignments").document())

        assignment_data = {
            "title": request.title,
            "description": request.description or "",
            "dueDate": request.due_date,
            "createdAt": datetime.datetime.utcnow(),
            "createdBy": current_user['uid'],
        }
        asg_ref.set(assignment_data)

        return {"message": "Assignment created", "assignment_id": asg_ref.id}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to create assignment: {str(e)}")

@app.get("/api/v1/classes/{class_id}/assignments")
async def list_assignments(class_id: str, current_user: dict = Depends(get_current_user)):
    """List assignments for a class (students and instructors)."""
    try:
        member_doc = db.collection("classMembers").document(f"{class_id}_{current_user['uid']}").get()
        if not member_doc.exists:
            raise HTTPException(status_code=403, detail="Not a member of this class")

        q = (db.collection("classes").document(class_id)
             .collection("assignments")
             .order_by("createdAt", direction=firestore.Query.DESCENDING))
        results = []
        for doc in q.stream():
            d = doc.to_dict()
            results.append({
                "assignment_id": doc.id,
                "title": d.get("title"),
                "description": d.get("description", ""),
                "due_date": serialize_datetime(d.get("dueDate")) if isinstance(d.get("dueDate"), datetime.datetime) else d.get("dueDate"),
                "created_at": serialize_datetime(d.get("createdAt")),
            })
        return {"assignments": results}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to list assignments: {str(e)}")

@app.get("/api/v1/classes/{class_id}/roster")
async def get_class_roster(class_id: str, current_user: dict = Depends(get_current_user)):
    """Get class roster. Students see classmates; instructors see all students and their roles."""
    try:
        # Check if user is a member (student OR instructor) - this was the bug!
        member_doc = db.collection("classMembers").document(f"{class_id}_{current_user['uid']}").get()
        if not member_doc.exists:
            raise HTTPException(status_code=403, detail="Not a member of this class")
        
        caller_role = member_doc.to_dict().get("role", "student")

        # Get all members of the class
        members = db.collection("classMembers").where("classId", "==", class_id).stream()
        roster = []
        for m in members:
            mdata = m.to_dict()
            user_id = mdata.get("userId")
            user_doc = db.collection("users").document(user_id).get()
            u = user_doc.to_dict() if user_doc.exists else {}
            roster.append({
                "user_id": user_id,
                "full_name": u.get("full_name", "Unknown"),
                "email": u.get("email", ""),  # Add email for better display
                "role": mdata.get("role", "student"),
                "joined_at": serialize_datetime(mdata.get("joinedAt")),
            })

        return {"roster": roster, "viewer_role": caller_role}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get roster: {str(e)}")

@app.delete("/api/v1/classes/{class_id}/roster/{student_id}")
async def remove_student_from_class(class_id: str, student_id: str, current_user: dict = Depends(get_current_user)):
    """Remove a student from a class (instructors only)."""
    try:
        member_doc = db.collection("classMembers").document(f"{class_id}_{current_user['uid']}").get()
        if not member_doc.exists or member_doc.to_dict().get("role") != "instructor":
            raise HTTPException(status_code=403, detail="Only instructors can remove students")

        # Ensure target student is in class
        target_doc = db.collection("classMembers").document(f"{class_id}_{student_id}").get()
        if not target_doc.exists:
            raise HTTPException(status_code=404, detail="Student not in this class")

        db.collection("classMembers").document(f"{class_id}_{student_id}").delete()
        return {"message": "Student removed"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to remove student: {str(e)}")

@app.post("/api/v1/classes/{class_id}/grades/set")
async def set_student_grade(class_id: str, request: SetGradeRequest, student_id: str, current_user: dict = Depends(get_current_user)):
    """Set a grade for a student on an assignment (instructors only)."""
    try:
        member_doc = db.collection("classMembers").document(f"{class_id}_{current_user['uid']}").get()
        if not member_doc.exists or member_doc.to_dict().get("role") != "instructor":
            raise HTTPException(status_code=403, detail="Only instructors can set grades")
        # Ensure student is in class
        stu_doc = db.collection("classMembers").document(f"{class_id}_{student_id}").get()
        if not stu_doc.exists:
            raise HTTPException(status_code=404, detail="Student not in this class")

        grade_ref = (db.collection("classes").document(class_id)
                     .collection("grades").document(f"{request.assignment_id}_{student_id}"))
        grade_ref.set({
            "assignmentId": request.assignment_id,
            "studentId": student_id,
            "grade": request.grade,
            "updatedAt": datetime.datetime.utcnow(),
            "updatedBy": current_user['uid'],
        })
        return {"message": "Grade saved"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to set grade: {str(e)}")

@app.get("/api/v1/classes/{class_id}/grades/student/{student_id}")
async def get_student_grades(class_id: str, student_id: str, current_user: dict = Depends(get_current_user)):
    """Get all grades for a student in a class. Students can view their own; instructors can view any."""
    try:
        caller_member = db.collection("classMembers").document(f"{class_id}_{current_user['uid']}").get()
        if not caller_member.exists:
            raise HTTPException(status_code=403, detail="Not a member of this class")
        caller_role = caller_member.to_dict().get("role")
        if current_user['uid'] != student_id and caller_role != "instructor":
            raise HTTPException(status_code=403, detail="Not allowed")

        q = db.collection("classes").document(class_id).collection("grades").where("studentId", "==", student_id)
        grades = []
        total = 0.0
        count = 0
        for gdoc in q.stream():
            g = gdoc.to_dict()
            grades.append({
                "assignment_id": g.get("assignmentId"),
                "grade": g.get("grade"),
                "updated_at": serialize_datetime(g.get("updatedAt")),
            })
            if isinstance(g.get("grade"), (int, float)):
                total += float(g.get("grade"))
                count += 1
        final_grade = (total / count) if count else None
        return {"grades": grades, "final_grade": final_grade}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get student grades: {str(e)}")

@app.get("/api/v1/classes/{class_id}/grades/assignment/{assignment_id}")
async def get_assignment_grades(class_id: str, assignment_id: str, current_user: dict = Depends(get_current_user)):
    """List all student grades for an assignment (instructors only)."""
    try:
        member_doc = db.collection("classMembers").document(f"{class_id}_{current_user['uid']}").get()
        if not member_doc.exists or member_doc.to_dict().get("role") != "instructor":
            raise HTTPException(status_code=403, detail="Only instructors can view assignment grades")

        q = (db.collection("classes").document(class_id)
             .collection("grades").where("assignmentId", "==", assignment_id))
        results = []
        for gdoc in q.stream():
            g = gdoc.to_dict()
            user_doc = db.collection("users").document(g.get("studentId", "")).get()
            u = user_doc.to_dict() if user_doc.exists else {}
            results.append({
                "student_id": g.get("studentId"),
                "student_name": u.get("full_name", "Unknown"),
                "grade": g.get("grade"),
                "updated_at": serialize_datetime(g.get("updatedAt")),
            })
        return {"grades": results}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get assignment grades: {str(e)}")


@app.get("/api/v1/posts/{post_id}")
async def get_post_details(post_id: str, current_user: dict = Depends(get_current_user)):
    """Get specific post details"""
    try:
        # This is a simplified implementation - you'd need to find the post across classes
        # or store class_id with the post_id in the request
        
        # For now, return a placeholder response
        return {
            "error": "This endpoint needs class_id context to locate the post",
            "suggestion": "Use /api/v1/classes/{class_id} to get posts within a class context"
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get post: {str(e)}")
    

@app.post("/api/v1/ai-study-buddy/with-files")
async def chat_with_study_buddy_files(
    message: str = "",
    conversation_id: Optional[str] = None,
    class_context: Optional[str] = None,
    files: List[UploadFile] = File(default=[]),
    current_user: dict = Depends(get_current_user)
):
    """Chat with AI Study Buddy including file analysis"""
    try:
        if not OPENAI_API_KEY or OPENAI_API_KEY == "your-openai-api-key-here":
            raise HTTPException(status_code=503, detail="AI service not configured")
        
        # Process uploaded files
        files_content = []
        file_types = []
        
        for file in files:
            if file.filename.lower().endswith('.pdf'):
                pdf_text = extract_pdf_text(file)
                files_content.append({
                    "type": "text",
                    "content": f"PDF content from {file.filename}:\n{pdf_text[:2000]}"  # Limit length
                })
                file_types.append("pdf")
                
            elif file.filename.lower().endswith(('.png', '.jpg', '.jpeg')):
                base64_image = process_image(file)
                files_content.append({
                    "type": "image_url",
                    "image_url": {"url": base64_image}
                })
                file_types.append("image")
        
        # Generate or use existing conversation ID
        conversation_id = conversation_id or str(uuid.uuid4())
        
        # Get or create conversation history
        conv_doc_ref = db.collection("ai_conversations").document(conversation_id)
        conv_doc = conv_doc_ref.get()
        
        if conv_doc.exists:
            conv_data = conv_doc.to_dict()
            conversation_history = conv_data.get("messages", [])
        else:
            conversation_history = [
                {"role": "system", "content": STUDY_BUDDY_SYSTEM_PROMPT}
            ]
        
        # Create user message
        user_message = message if message else "Can you help me understand these files?"
        conversation_history.append({"role": "user", "content": user_message})
        
        # Get class context if provided
        class_context_text = ""
        if class_context:
            class_context_text = get_class_context(class_context, db)
        
        # Get AI response with files
        ai_response = get_ai_response_with_files(
            conversation_history, 
            OPENAI_API_KEY, 
            files_content,
            class_context_text
        )
        
        # Add AI response to history
        conversation_history.append({"role": "assistant", "content": ai_response})
        
        # Save conversation to Firestore
        conv_data = {
            "conversation_id": conversation_id,
            "messages": conversation_history,
            "class_id": class_context,
            "user_id": current_user['uid'],
            "created_at": conv_doc.get("created_at") if conv_doc.exists else datetime.datetime.utcnow(),
            "last_updated": datetime.datetime.utcnow(),
            "file_types": file_types
        }
        conv_doc_ref.set(conv_data)
        
        return {
            "response": ai_response,
            "conversation_id": conversation_id,
            "timestamp": datetime.datetime.utcnow().isoformat(),
            "processed_files": len(files),
            "file_types": file_types
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"File analysis error: {str(e)}")
    

@app.post("/api/v1/notes/analyze", response_model=SummaryResponse)
async def analyze_notes_to_json(
    files: List[UploadFile] = File(...),
    class_id: str = Form(...),
    title: Optional[str] = Form(None),
    current_user: dict = Depends(get_current_user)
):
    """Analyze uploaded files and return structured JSON summary"""
    try:
        if not OPENAI_API_KEY or OPENAI_API_KEY == "your-openai-api-key-here":
            raise HTTPException(status_code=503, detail="AI service not configured")
        
        if not files:
            raise HTTPException(status_code=400, detail="No files uploaded")
        
        # Process files and combine content
        combined_content = ""
        file_sources = []
        
        for file in files:
            file_sources.append(file.filename)
            
            if file.filename.lower().endswith('.pdf'):
                pdf_text = extract_pdf_text(file)
                combined_content += f"\n\n--- Content from {file.filename} ---\n{pdf_text}"
                
            elif file.filename.lower().endswith(('.png', '.jpg', '.jpeg')):
                # Use OpenAI Vision API to extract text from image
                image_text = extract_text_from_image(file, OPENAI_API_KEY)
                combined_content += f"\n\n--- Content from {file.filename} ---\n{image_text}"
            
            elif file.filename.lower().endswith('.txt'):
                text_content = (await file.read()).decode('utf-8')
                combined_content += f"\n\n--- Content from {file.filename} ---\n{text_content}"
        
        if not combined_content.strip():
            raise HTTPException(status_code=400, detail="No readable content found in uploaded files")
        
        # Get structured summary from AI
        summary_data = get_structured_summary(
            combined_content,
            OPENAI_API_KEY,
            title
        )

        # Generate summary ID and create database document
        summary_id = str(uuid.uuid4())

        # Use provided title or AI-generated one
        final_title = title or summary_data.get("title", "Study Notes")
        
        # Create NoteSummary object
        note_summary = NoteSummary(
            summary_id=summary_id,
            title=final_title,
            key_concepts=summary_data.get("key_concepts", []),
            main_points=summary_data.get("main_points", []),
            study_tips=summary_data.get("study_tips", []),
            questions_for_review=summary_data.get("questions_for_review", []),
            difficulty_level=summary_data.get("difficulty_level", "intermediate"),
            estimated_study_time=summary_data.get("estimated_study_time", "30 minutes"),
            created_at=datetime.datetime.utcnow().isoformat(),
            file_sources=file_sources,  # Original filenames
            class_id=class_id,
            user_id=current_user['uid']
        )
        
        # Store in Firestore
        summary_doc = {
            "summary_id": summary_id,
            "title": final_title,
            "key_concepts": summary_data.get("key_concepts", []),
            "main_points": summary_data.get("main_points", []),
            "study_tips": summary_data.get("study_tips", []),
            "questions_for_review": summary_data.get("questions_for_review", []),
            "difficulty_level": summary_data.get("difficulty_level", "intermediate"),
            "estimated_study_time": summary_data.get("estimated_study_time", "30 minutes"),
            "created_at": datetime.datetime.utcnow(),
            "file_sources": file_sources,
            "class_id": class_id,
            "user_id": current_user['uid'],
            "raw_content": combined_content[:1000]  # Store preview of original content
        }

        # Save as subcollection under the class
        db.collection("classes").document(class_id).collection("note_summaries").document(summary_id).set(summary_doc)

        return SummaryResponse(
            summary=note_summary,
            raw_content_preview=combined_content[:200] + "..." if len(combined_content) > 200 else combined_content
        )
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Note analysis failed: {str(e)}")

# Get note summaries for a specific class
@app.get("/api/v1/classes/{class_id}/note_summaries")
async def get_class_note_summaries(
    class_id: str,
    limit: int = 50,
    current_user: dict = Depends(get_current_user)
):
    """Get note summaries for a specific class"""
    try:
        # Fetch summaries from the class's subcollection (shared with all students)
        summaries_ref = db.collection("classes").document(class_id).collection("note_summaries")
        # All students can see all notes in this class
        summaries = summaries_ref.order_by("created_at", direction=firestore.Query.DESCENDING).limit(limit).stream()

        summary_list = []
        for summary_doc in summaries:
            summary_data = summary_doc.to_dict()
            summary_list.append({
                "summary_id": summary_data.get("summary_id"),
                "title": summary_data.get("title"),
                "difficulty_level": summary_data.get("difficulty_level"),
                "estimated_study_time": summary_data.get("estimated_study_time"),
                "created_at": serialize_datetime(summary_data.get("created_at")),
                "file_sources": summary_data.get("file_sources", []),
                "class_id": summary_data.get("class_id"),
                "concept_count": len(summary_data.get("key_concepts", [])),
                # Include full content for frontend display
                "key_concepts": summary_data.get("key_concepts", []),
                "main_points": summary_data.get("main_points", []),
                "study_tips": summary_data.get("study_tips", []),
                "questions_for_review": summary_data.get("questions_for_review", [])
            })
        
        return {"summaries": summary_list}
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get summaries: {str(e)}")

# Get specific summary details
@app.get("/api/v1/summaries/{summary_id}", response_model=NoteSummary)
async def get_summary_details(
    summary_id: str,
    current_user: dict = Depends(get_current_user)
):
    """Get detailed summary by ID"""
    try:
        summary_doc = db.collection("note_summaries").document(summary_id).get()
        
        if not summary_doc.exists:
            raise HTTPException(status_code=404, detail="Summary not found")
        
        summary_data = summary_doc.to_dict()
        
        # Verify ownership
        if summary_data.get("user_id") != current_user['uid']:
            raise HTTPException(status_code=403, detail="Access denied")
        
        return NoteSummary(
            summary_id=summary_data.get("summary_id"),
            title=summary_data.get("title"),
            key_concepts=summary_data.get("key_concepts", []),
            main_points=summary_data.get("main_points", []),
            study_tips=summary_data.get("study_tips", []),
            questions_for_review=summary_data.get("questions_for_review", []),
            difficulty_level=summary_data.get("difficulty_level", "intermediate"),
            estimated_study_time=summary_data.get("estimated_study_time", "30 minutes"),
            created_at=serialize_datetime(summary_data.get("created_at")),
            file_sources=summary_data.get("file_sources", []),
            class_id=summary_data.get("class_id"),
            user_id=summary_data.get("user_id")
        )
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get summary: {str(e)}")

# Get summaries for a specific class
@app.get("/api/v1/classes/{class_id}/summaries")
async def get_class_summaries(

    class_id: str,
    limit: int = 50,
    current_user: dict = Depends(get_current_user)
):
    """Get all summaries for a specific class (shared with all class members)"""
    try:
        # Verify user is member of class
        member_doc = db.collection("classMembers").document(f"{class_id}_{current_user['uid']}").get()
        if not member_doc.exists:
            raise HTTPException(status_code=403, detail="Not a member of this class")

        # Query ALL summaries for this class (not just current user's)
        query = db.collection("note_summaries").where("class_id", "==", class_id)
        summaries = query.order_by("created_at", direction=firestore.Query.DESCENDING).limit(limit).stream();

        summary_list = []
        for summary_doc in summaries:
            summary_data = summary_doc.to_dict();

            # Get the creator's name
            creator_name = "Unknown"
            creator_id = summary_data.get("user_id")
            if creator_id:
                try:
                    user_doc = db.collection("users").document(creator_id).get()
                    if user_doc.exists:
                        creator_name = user_doc.to_dict().get("full_name", "Unknown")
                except Exception:
                    pass

            summary_list.append({
                "summary_id": summary_data.get("summary_id"),
                "title": summary_data.get("title"),
                "difficulty_level": summary_data.get("difficulty_level"),
                "estimated_study_time": summary_data.get("estimated_study_time"),
                "created_at": serialize_datetime(summary_data.get("created_at")),
                "file_sources": summary_data.get("file_sources", []),
                "class_id": summary_data.get("class_id"),
                "concept_count": len(summary_data.get("key_concepts", [])),
                "user_id": creator_id,
                "created_by": creator_name
            })

        return {"summaries": summary_list}

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get class summaries: {str(e)}")

# -------------------------------
# Notes CRUD Endpoints
# -------------------------------

# Create a new note
@app.post("/api/v1/notes", response_model=Note)
async def create_note(
    request: CreateNoteRequest,
    current_user: dict = Depends(get_current_user)
):
    """Create a new note"""
    try:
        note_id = str(uuid.uuid4())
        now = datetime.datetime.utcnow()

        note_doc = {
            "note_id": note_id,
            "title": request.title,
            "content": request.content,
            "class_id": request.class_id,
            "user_id": current_user['uid'],
            "created_at": now,
            "updated_at": now
        }
        
        # Add linked summary if provided
        if request.linked_summary_id:
            note_doc["linked_summary_id"] = request.linked_summary_id

        # Save as subcollection under the user
        db.collection("users").document(current_user['uid']).collection("notes").document(note_id).set(note_doc)

        return Note(
            note_id=note_id,
            title=request.title,
            content=request.content,
            class_id=request.class_id,
            user_id=current_user['uid'],
            created_at=now.isoformat(),
            updated_at=now.isoformat()
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to create note: {str(e)}")

# Get all notes for current user
@app.get("/api/v1/notes")
async def get_notes(
    class_id: Optional[str] = None,
    limit: int = 50,
    current_user: dict = Depends(get_current_user)
):
    """Get user's notes, optionally filtered by class"""
    try:
        # Fetch from user's subcollection
        query = db.collection("users").document(current_user['uid']).collection("notes")

        if class_id:
            query = query.where("class_id", "==", class_id)

        # Retrieve notes without ordering to avoid needing a composite index
        # We'll sort them in memory instead
        notes = query.limit(limit).stream()

        notes_list = []
        for note_doc in notes:
            note_data = note_doc.to_dict()
            notes_list.append({
                "note_id": note_data.get("note_id"),
                "title": note_data.get("title"),
                "content": note_data.get("content"),
                "class_id": note_data.get("class_id"),
                "user_id": note_data.get("user_id"),
                "created_at": serialize_datetime(note_data.get("created_at")),
                "updated_at": serialize_datetime(note_data.get("updated_at")),
                "_sort_key": note_data.get("updated_at")  # Keep for sorting
            })

        # Sort by updated_at in memory (most recent first)
        notes_list.sort(key=lambda x: x.get("_sort_key") or datetime.datetime.min, reverse=True)

        # Remove the temporary sort key before returning
        for note in notes_list:
            note.pop("_sort_key", None)

        return {"notes": notes_list}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get notes: {str(e)}")

# Get a specific note by ID
@app.get("/api/v1/notes/{note_id}", response_model=Note)
async def get_note(
    note_id: str,
    current_user: dict = Depends(get_current_user)
):
    """Get a specific note by ID"""
    try:
        # Fetch from user's subcollection
        note_doc = db.collection("users").document(current_user['uid']).collection("notes").document(note_id).get()

        if not note_doc.exists:
            raise HTTPException(status_code=404, detail="Note not found")

        note_data = note_doc.to_dict()

        return Note(
            note_id=note_data.get("note_id"),
            title=note_data.get("title"),
            content=note_data.get("content"),
            class_id=note_data.get("class_id"),
            user_id=note_data.get("user_id"),
            created_at=serialize_datetime(note_data.get("created_at")),
            updated_at=serialize_datetime(note_data.get("updated_at"))
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get note: {str(e)}")

# Update a note
@app.put("/api/v1/notes/{note_id}", response_model=Note)
async def update_note(
    note_id: str,
    request: UpdateNoteRequest,
    current_user: dict = Depends(get_current_user)
):
    """Update a note"""
    try:
        # Fetch from user's subcollection
        note_ref = db.collection("users").document(current_user['uid']).collection("notes").document(note_id)
        note_doc = note_ref.get()

        if not note_doc.exists:
            raise HTTPException(status_code=404, detail="Note not found")

        note_data = note_doc.to_dict()

        # Build update data
        update_data = {"updated_at": datetime.datetime.utcnow()}
        if request.title is not None:
            update_data["title"] = request.title
        if request.content is not None:
            update_data["content"] = request.content

        note_ref.update(update_data)

        # Get updated note
        updated_doc = note_ref.get()
        updated_data = updated_doc.to_dict()

        return Note(
            note_id=updated_data.get("note_id"),
            title=updated_data.get("title"),
            content=updated_data.get("content"),
            class_id=updated_data.get("class_id"),
            user_id=updated_data.get("user_id"),
            created_at=serialize_datetime(updated_data.get("created_at")),
            updated_at=serialize_datetime(updated_data.get("updated_at"))
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to update note: {str(e)}")

# Delete a note
@app.delete("/api/v1/notes/{note_id}")
async def delete_note(
    note_id: str,
    current_user: dict = Depends(get_current_user)
):
    """Delete a note"""
    try:
        # Fetch from user's subcollection
        note_ref = db.collection("users").document(current_user['uid']).collection("notes").document(note_id)
        note_doc = note_ref.get()

        if not note_doc.exists:
            raise HTTPException(status_code=404, detail="Note not found")

        note_ref.delete()

        return {"message": "Note deleted successfully"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to delete note: {str(e)}")

@app.get("/api/v1/notes/{note_id}/with-summary")
async def get_note_with_linked_summary(
    note_id: str,
    current_user: dict = Depends(get_current_user)
):
    """Get a note with its linked summary details"""
    try:
        note_ref = db.collection("users").document(current_user['uid']).collection("notes").document(note_id)
        note_doc = note_ref.get()

        if not note_doc.exists:
            raise HTTPException(status_code=404, detail="Note not found")

        note_data = note_doc.to_dict()
        linked_summary_id = note_data.get("linked_summary_id")

        result = {
            "note": {
                "note_id": note_data.get("note_id"),
                "title": note_data.get("title"),
                "content": note_data.get("content"),
                "class_id": note_data.get("class_id"),
                "user_id": note_data.get("user_id"),
                "created_at": serialize_datetime(note_data.get("created_at")),
                "updated_at": serialize_datetime(note_data.get("updated_at")),
                "linked_summary_id": linked_summary_id
            },
            "summary": None
        }

        # Fetch linked summary if it exists
        if linked_summary_id:
            class_id = note_data.get("class_id")
            if class_id:
                summary_doc = db.collection("classes").document(class_id).collection("note_summaries").document(linked_summary_id).get()
                if summary_doc.exists:
                    summary_data = summary_doc.to_dict()
                    result["summary"] = {
                        "summary_id": summary_data.get("summary_id"),
                        "title": summary_data.get("title"),
                        "key_concepts": summary_data.get("key_concepts", []),
                        "main_points": summary_data.get("main_points", []),
                        "study_tips": summary_data.get("study_tips", []),
                        "questions_for_review": summary_data.get("questions_for_review", []),
                        "difficulty_level": summary_data.get("difficulty_level"),
                        "estimated_study_time": summary_data.get("estimated_study_time"),
                        "created_at": serialize_datetime(summary_data.get("created_at"))
                    }

        return result
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get note with summary: {str(e)}")


@app.get("/api/v1/summaries/{summary_id}/linked-notes")
async def get_notes_linked_to_summary(
    summary_id: str,
    class_id: str,
    current_user: dict = Depends(get_current_user)
):
    """Get all user notes linked to a specific summary"""
    try:
        # Verify user is member of class
        member_doc = db.collection("classMembers").document(f"{class_id}_{current_user['uid']}").get()
        if not member_doc.exists:
            raise HTTPException(status_code=403, detail="Not a member of this class")

        # Query user's notes that are linked to this summary
        query = (db.collection("users").document(current_user['uid']).collection("notes")
                .where("linked_summary_id", "==", summary_id)
                .where("class_id", "==", class_id))
        
        notes = query.stream()
        notes_list = []
        
        for note_doc in notes:
            note_data = note_doc.to_dict()
            notes_list.append({
                "note_id": note_data.get("note_id"),
                "title": note_data.get("title"),
                "content": note_data.get("content"),
                "created_at": serialize_datetime(note_data.get("created_at")),
                "updated_at": serialize_datetime(note_data.get("updated_at"))
            })

        return {"notes": notes_list, "summary_id": summary_id}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get linked notes: {str(e)}")


@app.post("/api/v1/notes/summarize", response_model=SummaryResponse)
async def create_summary_from_notes(
    request: SummarizeNotesRequest,
    current_user: dict = Depends(get_current_user)
):
    """Create AI summary from existing user notes"""
    try:
        if not OPENAI_API_KEY or OPENAI_API_KEY == "your-openai-api-key-here":
            raise HTTPException(status_code=503, detail="AI service not configured")
        
        if not request.note_ids:
            raise HTTPException(status_code=400, detail="No notes selected")

        # Verify user is member of class
        member_doc = db.collection("classMembers").document(f"{request.class_id}_{current_user['uid']}").get()
        if not member_doc.exists:
            raise HTTPException(status_code=403, detail="Not a member of this class")

        # Fetch and combine note content
        combined_content = ""
        note_titles = []
        
        for note_id in request.note_ids:
            note_ref = db.collection("users").document(current_user['uid']).collection("notes").document(note_id)
            note_doc = note_ref.get()
            
            if not note_doc.exists:
                continue
                
            note_data = note_doc.to_dict()
            
            # Verify note belongs to the specified class
            if note_data.get("class_id") != request.class_id:
                continue
            
            note_titles.append(note_data.get("title", "Untitled"))
            combined_content += f"\n\n--- {note_data.get('title', 'Untitled')} ---\n{note_data.get('content', '')}"
        
        if not combined_content.strip():
            raise HTTPException(status_code=400, detail="No valid note content found")

        # Get structured summary from AI
        summary_data = get_structured_summary(
            combined_content,
            OPENAI_API_KEY,
            request.title
        )

        # Generate summary ID
        summary_id = str(uuid.uuid4())
        final_title = request.title or summary_data.get("title", f"Summary of {len(note_titles)} notes")

        # Create NoteSummary object
        note_summary = NoteSummary(
            summary_id=summary_id,
            title=final_title,
            key_concepts=summary_data.get("key_concepts", []),
            main_points=summary_data.get("main_points", []),
            study_tips=summary_data.get("study_tips", []),
            questions_for_review=summary_data.get("questions_for_review", []),
            difficulty_level=summary_data.get("difficulty_level", "intermediate"),
            estimated_study_time=summary_data.get("estimated_study_time", "30 minutes"),
            created_at=datetime.datetime.utcnow().isoformat(),
            file_sources=note_titles,  # Use note titles as "sources"
            class_id=request.class_id,
            user_id=current_user['uid']
        )

        # Store in Firestore
        summary_doc = {
            "summary_id": summary_id,
            "title": final_title,
            "key_concepts": summary_data.get("key_concepts", []),
            "main_points": summary_data.get("main_points", []),
            "study_tips": summary_data.get("study_tips", []),
            "questions_for_review": summary_data.get("questions_for_review", []),
            "difficulty_level": summary_data.get("difficulty_level", "intermediate"),
            "estimated_study_time": summary_data.get("estimated_study_time", "30 minutes"),
            "created_at": datetime.datetime.utcnow(),
            "file_sources": note_titles,
            "class_id": request.class_id,
            "user_id": current_user['uid'],
            "raw_content": combined_content[:1000],
            "source_type": "user_notes",  # Track that this came from user notes
            "source_note_ids": request.note_ids  # Track which notes were used
        }

        # Save to class's note_summaries subcollection
        db.collection("classes").document(request.class_id).collection("note_summaries").document(summary_id).set(summary_doc)

        # Optionally: Update the source notes to link back to this summary
        for note_id in request.note_ids:
            note_ref = db.collection("users").document(current_user['uid']).collection("notes").document(note_id)
            note_ref.update({"linked_summary_id": summary_id})

        return SummaryResponse(
            summary=note_summary,
            raw_content_preview=combined_content[:200] + "..." if len(combined_content) > 200 else combined_content
        )

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to create summary from notes: {str(e)}")


@app.put("/api/v1/notes/{note_id}/link-summary")
async def link_note_to_summary(
    note_id: str,
    summary_id: str,
    current_user: dict = Depends(get_current_user)
):
    """Link an existing note to a summary"""
    try:
        note_ref = db.collection("users").document(current_user['uid']).collection("notes").document(note_id)
        note_doc = note_ref.get()

        if not note_doc.exists:
            raise HTTPException(status_code=404, detail="Note not found")

        # Update the note with the linked summary
        note_ref.update({
            "linked_summary_id": summary_id,
            "updated_at": datetime.datetime.utcnow()
        })

        return {"message": "Note linked to summary successfully", "note_id": note_id, "summary_id": summary_id}
    
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to link note: {str(e)}")


@app.delete("/api/v1/notes/{note_id}/unlink-summary")
async def unlink_note_from_summary(
    note_id: str,
    current_user: dict = Depends(get_current_user)
):
    """Remove summary link from a note"""
    try:
        note_ref = db.collection("users").document(current_user['uid']).collection("notes").document(note_id)
        note_doc = note_ref.get()

        if not note_doc.exists:
            raise HTTPException(status_code=404, detail="Note not found")

        # Remove the linked summary
        note_ref.update({
            "linked_summary_id": firestore.DELETE_FIELD,
            "updated_at": datetime.datetime.utcnow()
        })

        return {"message": "Note unlinked from summary successfully", "note_id": note_id}
    
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to unlink note: {str(e)}")

# -------------------------------
# Health Check
# -------------------------------
@app.get("/")
async def health_check():
    return {"message": "Classroom API v1.0.0 is running ✅", "timestamp": datetime.datetime.utcnow().isoformat()}

if __name__ == "__main__":
    import uvicorn
    import os
    port = int(os.environ.get("PORT", 8080))
    uvicorn.run(app, host="0.0.0.0", port=port)