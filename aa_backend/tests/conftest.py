import sys
from pathlib import Path

# Make aa_backend/main.py importable as `main` from within tests/.
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
