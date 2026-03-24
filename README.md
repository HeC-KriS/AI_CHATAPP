## AI Chat App (Flutter + Docker + Multi-Model AI)

A cross-platform AI chat application built using Flutter and a Python backend, powered by multiple AI models running locally using Docker.

This project allows users to interact with different AI models (fast, lightweight, and smart) through a single unified chat interface.

## Features
Real-time chat interface
Cross-platform (Android, iOS, Web, Desktop)
Multiple AI models support
Docker-based model deployment
Fast API communication
Switch between models dynamically for specific tasks
It stores the chat history in neondb



## Architecture
The app follows a bridge-pattern to connect a mobile frontend to a heavy-duty local AI engine.

Mobile Frontend (Flutter): Provides a smooth, Flutter_Markdown support for clean AI responses.

Backend Gateway (FastAPI): Managed Python bridge that handles user authentication and stores chat history in NeonDB. It acts as a bridge between the model,database and flutterapp. It provides a nice backend ui which can be used to try out

Local AI Engine (Docker): Runs quantized models (Qwen, Llama, Gemma) using Docker, Docker runs much faster than ollama as it directly connects with the hardware. It is preferred to use atleast 6gb vram gpu for the project.

## Quick Start

1) Enable these settings in Docker to use the run the model effectively

<img width="1604" height="894" alt="image" src="https://github.com/user-attachments/assets/9ab5c8bd-3aa8-475d-bd75-00efb06e36b0" />

2)Install these models llama3.2:1B-Q8_0, qwen2.5:3B-Q4_K_M, gemma3:1B-Q4_K_M. Click pull for all the three models

<img width="1590" height="898" alt="image" src="https://github.com/user-attachments/assets/544f3af1-aa1c-40ca-8577-a4e0bc9a4031" />

3)now create a neon database using link "https://console.neon.tech/app/projects/lingering-fog-97973274?database=neondb&branchId=br-fragrant-night-a1sdz9zs" login and click connect and copy the url

<img width="1916" height="877" alt="image" src="https://github.com/user-attachments/assets/65555a29-59b3-4bc9-9624-7d1fd3fa5689" />

4)Now paste this url in .env file in the same directory as backend.py DATABASE_URL=copiedurl

5)Now verify run the command 

pip install -r requirements.txt

6)run backend.py and open localhost:8000/docs and verify

<img width="1878" height="832" alt="image" src="https://github.com/user-attachments/assets/12c8fe28-6441-4313-ba25-41cdb6778b02" />

7)cd frontend/chatapp

8)flutter pub get

9)now go to ur terminal and type ipconfig/ anyother way to copy your device ipaddress


10)paste this ipadress in api_service in the place of ipaddress

11)Now run flutter pub get

12)Connect ur phone via usb and ensure that ur laptop and phone is connected in same wifi

13)Run Flutter run command
