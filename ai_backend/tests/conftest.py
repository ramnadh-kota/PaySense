import os
import sys
from pathlib import Path

# Make ai_backend/main.py importable as `main` from within tests/.
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

# main.py reads OPENAI_API_KEY at import time; use an obviously-fake value so
# tests never depend on (or risk touching) a real OpenAI credential.
os.environ.setdefault("OPENAI_API_KEY", "test-key-not-real")
