import json
import threading
import time
import bisect
import subprocess
import urllib.request
import random
import os
import re
from pathlib import Path
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

BASE = Path(__file__).parent.resolve()

# Load frequency dictionary
FREQ_PATH = BASE / "freq_lookup.json"
FREQ = {}
if FREQ_PATH.exists():
    try:
        with open(FREQ_PATH, "r", encoding="utf-8") as f:
            FREQ = json.load(f)
        print(f"Loaded {len(FREQ)} frequency entries from {FREQ_PATH.name}")
    except Exception as e:
        print(f"Error loading frequency dictionary: {e}")

# Initialize Janome Tokenizer
try:
    from janome.tokenizer import Tokenizer

    TOKENIZER = Tokenizer()
    print("Janome morphological tokenizer initialized successfully.")
except Exception as e:
    print(f"Warning: Janome tokenizer not available: {e}")
    TOKENIZER = None


def annotate_text(text_line):
    """
    Tokenizes a Japanese text line and looks up the frequency rank for each token.
    Returns a list of dicts: {'s': surface, 'b': base_form, 'r': rank, 'p': pos}
    """
    if not TOKENIZER:
        return []
    tokens = []
    try:
        for tok in TOKENIZER.tokenize(text_line):
            surface = tok.surface
            base = tok.base_form if tok.base_form != "*" else surface
            pos = tok.part_of_speech.split(",")[0]

            rank = FREQ.get(base)
            if rank is None:
                rank = FREQ.get(surface)

            # Check for inflected stems (e.g. adverbs/na-adjectives ending in に or な)
            if (
                (rank is None or rank > 10000)
                and (surface.endswith("に") or surface.endswith("な"))
                and len(surface) > 1
            ):
                stem_rank = FREQ.get(surface[:-1])
                if stem_rank is not None and (rank is None or stem_rank < rank):
                    rank = stem_rank

            tokens.append({"s": surface, "b": base, "r": rank, "p": pos})
    except Exception as e:
        print(f"Tokenization error on line '{text_line}': {e}")
        return []
    return tokens


def to_ms(h=0, m=0, s=0, ms=0):
    return ms + 1000 * (s + 60 * (m + 60 * h))


def parse_srt(srt):
    def parse_ts(ts):
        hh, mm, rest = ts.split(":")
        ss, ms = rest.split(",")

        hh = int(hh)
        mm = int(mm)
        ss = int(ss)
        ms = int(ms)

        return to_ms(hh, mm, ss, ms), f"{hh}:{mm:02}:{round(ss + ms / 1000):02}"

    def parse_times(time: str):
        start, end = time.strip().split("-->")
        start = parse_ts(start.rstrip())
        end = parse_ts(end.lstrip())

        return *start, *end

    lines = [v.replace("{\\an8}", "").split("\n") for v in srt.rstrip().split("\n\n")]

    return [[rest, *parse_times(time)] for _, time, *rest in lines]


def parse_ass(ass):
    def parse_ts(ts):
        # h:mm:ss.cc
        parts = ts.split(":")
        h = int(parts[0])
        m = int(parts[1])
        s, cs = parts[2].split(".")
        s = int(s)
        ms = int(cs) * 10

        return to_ms(h, m, s, ms), f"{h}:{m:02}:{round(s + ms / 1000):02}"

    lines = []
    format_cols = []

    # Simple regex for stripping ASS tags { ... }
    tag_re = re.compile(r"\{[^}]+\}")

    for line in ass.splitlines():
        line = line.strip()
        if line.startswith("Format:"):
            # Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
            format_cols = [x.strip().lower() for x in line[7:].split(",")]
        elif line.startswith("Dialogue:"):
            if not format_cols:
                continue

            # Parse CSV, Text is the last column and may handle commas
            parts = line[9:].split(",", len(format_cols) - 1)
            if len(parts) != len(format_cols):
                continue

            row = dict(zip(format_cols, parts))

            start_ms, start_str = parse_ts(row.get("start", "0:00:00.00"))
            end_ms, end_str = parse_ts(row.get("end", "0:00:00.00"))

            text = row.get("text", "")
            text = tag_re.sub("", text)
            text = text.replace("\\N", "\n").replace("\\n", "\n").replace("\\h", " ")

            # Lines format: [[lines list], start_ms, start_str, end_ms, end_str]
            text_lines = text.split("\n")
            lines.append([text_lines, start_ms, start_str, end_ms, end_str])

    lines.sort(key=lambda x: x[1])
    return lines


def token():
    return random.randbytes(8).hex()


DELIM = re.compile(r"(「|」|『|』|\"|\'|\.|!|\?|．|。|…|︒|！|？|︙|\s|<b>|</b>|\uFEFF)")


def normalize_str(s):
    return DELIM.sub("", s)


ID = ""
FILE = ""
AID = None
LINES = []
NORMALIZED = []
IGNORE = set()
DELAY = 0

DEFAULT_OPTIONS = {
    "deck": "",
    "sentence": "",
    "expression": "",
    "picture": "",
    "audio": "",
    "prev_lines": 0,
    "next_lines": 0,
    "freq_enabled": True,
    "freq_style": "underline",
    "freq_tier1_max": 1500,
    "freq_tier2_max": 5000,
    "freq_tier3_max": 10000,
    "freq_tier4_max": 25000,
    "show_tier1": True,
    "show_tier2": True,
    "show_tier3": True,
    "show_tier4": False,
    "show_tier5": False,
}

OPTIONS = dict(DEFAULT_OPTIONS)
OPTIONS_PATH = BASE / "options.json"
if OPTIONS_PATH.exists():
    try:
        with open(OPTIONS_PATH, "r", encoding="utf-8") as f:
            OPTIONS.update(json.load(f))
    except Exception as e:
        print(f"Error loading options: {e}")

CHECK_LOCK = threading.Lock()


def load_subs_content(content):
    global ID, LINES, NORMALIZED

    if not content:
        ID = ""
        LINES = []
        NORMALIZED = []
        return

    ID = token()
    try:
        if content.strip().startswith("[Script Info]") or "Dialogue:" in content:
            raw_lines = parse_ass(content)
        else:
            raw_lines = parse_srt(content)

        # Annotate lines with tokenized frequency info
        LINES = []
        for item in raw_lines:
            text_lines = item[0]
            tokens_per_line = [annotate_text(line) for line in text_lines]
            LINES.append([*item, tokens_per_line])

        NORMALIZED = [normalize_str("".join(line[0])) for line in LINES]
    except Exception as e:
        print(f"Error parsing subtitles: {e}")
        LINES = []
        NORMALIZED = []


def request(action, **params):
    return {"action": action, "params": params, "version": 6}


def invoke(action, **params):
    req_json = json.dumps(request(action, **params)).encode("utf-8")
    try:
        r = json.load(
            urllib.request.urlopen(
                urllib.request.Request("http://127.0.0.1:8765", req_json)
            )
        )
    except urllib.error.URLError:
        return None

    if len(r) != 2:
        return None
    if "error" not in r:
        return None
    if "result" not in r:
        return None
    if r["error"] is not None:
        return Exception(r["error"])

    return r["result"]


MPV_PATH = BASE / "../../mpv.exe"
MPV = str(MPV_PATH) if MPV_PATH.exists() else "mpv"

FFMPEG_PATH = BASE / "../../ffmpeg.exe"
FFMPEG = str(FFMPEG_PATH) if FFMPEG_PATH.exists() else "ffmpeg"


def extract_internal_subs(video_path, stream_index, fmt="srt"):
    try:
        startupinfo = None
        if os.name == "nt":
            startupinfo = subprocess.STARTUPINFO()
            startupinfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW

        cmd = [FFMPEG, "-i", video_path, "-map", f"0:{stream_index}", "-f", fmt, "-"]
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            encoding="utf-8",
            startupinfo=startupinfo,
        )
        if result.returncode != 0:
            print("FFmpeg error:", result.stderr)
            return None
        return result.stdout
    except Exception as e:
        print("Extraction failed:", e)
        return None


def take_screenshot(src, start, end):
    file = f"autocards-{token()}.webp"
    path = str(BASE / file)

    subprocess.run(
        [
            MPV,
            src,
            "--no-config",
            "--audio=no",
            "--no-ocopy-metadata",
            "--no-sub",
            "--frames=1",
            "--dscale=box",
            "--window-scale=0.5",
            "--screenshot-webp-quality=70",
            "--screenshot-webp-compression=3",
            f"--start={0.75 * start + 0.25 * end:.3f}",
            "-o",
            path,
        ]
    )

    r = invoke("storeMediaFile", filename=file, path=path)
    os.remove(path)

    return r


def take_audio(src, start, end, aid=None):
    file = f"autocards-{token()}.mp3"
    path = str(BASE / file)

    cmd = [
        MPV,
        src,
        "--no-config",
        "--video=no",
        "--no-ocopy-metadata",
        "--no-sub",
        "--audio-channels=1",
        f"--start={start:.3f}",
        f"--length={end - start:.3f}",
    ]
    if aid is not None:
        cmd.append(f"--aid={aid}")
    cmd.extend(["-o", path])

    subprocess.run(cmd)

    r = invoke("storeMediaFile", filename=file, path=path)
    os.remove(path)

    return r


def update_note(note_id, idx, expression=None, original_sentence=None):
    prev_lines = OPTIONS.get("prev_lines", 0)
    next_lines = OPTIONS.get("next_lines", 0)

    start_idx = max(0, idx - prev_lines)
    end_idx = min(len(LINES) - 1, idx + next_lines)

    lines_subset = LINES[start_idx : end_idx + 1]

    sentence = "<br/>".join("<br/>".join(line[0]) for line in lines_subset)

    words_to_bold = set()
    if expression:
        words_to_bold.add(expression)

    if original_sentence:
        words_to_bold.update(
            filter(None, re.findall(r"<b>(.*?)</b>", original_sentence))
        )

    if words_to_bold:
        sorted_words = sorted(words_to_bold, key=len, reverse=True)
        pattern_str = "|".join(re.escape(w) for w in sorted_words)
        sentence = re.sub(pattern_str, lambda m: f"<b>{m.group(0)}</b>", sentence)

    start = lines_subset[0][1] / 1000 + DELAY
    end = lines_subset[-1][3] / 1000 + DELAY

    picture = take_screenshot(FILE, start, end)
    sound = take_audio(FILE, start, end, aid=AID)

    invoke(
        "updateNote",
        note={
            "id": note_id,
            "fields": {
                OPTIONS["sentence"]: sentence,
                OPTIONS["picture"]: f'<img src="{picture}">',
                OPTIONS["audio"]: f"[sound:{sound}]",
            },
        },
    )

    print("updated note:", note_id)


def check(t):
    global IGNORE

    if not CHECK_LOCK.acquire(blocking=False):
        return

    try:
        if not ID:
            return

        for k, v in OPTIONS.items():
            if k in [
                "prev_lines",
                "next_lines",
                "freq_enabled",
                "freq_style",
                "freq_tier1_max",
                "freq_tier2_max",
                "freq_tier3_max",
                "freq_tier4_max",
                "show_tier1",
                "show_tier2",
                "show_tier3",
                "show_tier4",
                "show_tier5",
            ]:
                continue
            if not v:
                return

        BASE_QUERY = (
            f"deck:{OPTIONS['deck']} added:1 {OPTIONS['picture']}: {OPTIONS['audio']}: "
        )

        ids = invoke("findCards", query=BASE_QUERY)
        if not ids:
            return

        end_idx = bisect.bisect_left(LINES, to_ms(s=t), key=lambda v: v[1])
        subs = {v: i for i, v in enumerate(NORMALIZED[:end_idx])}

        notes = invoke("cardsInfo", cards=ids)

        filtered_cards = []
        for id, note_id in zip(ids, notes):
            if id in IGNORE:
                continue

            sentence = note_id["fields"][OPTIONS["sentence"]]["value"]
            expression = None
            if OPTIONS["expression"]:
                expression = note_id["fields"][OPTIONS["expression"]]["value"]

            idx = subs.get(normalize_str(sentence))
            if idx is None:
                continue

            filtered_cards.append((id, idx, expression, sentence))

        for id, idx, expression, sentence in filtered_cards:
            notes = invoke("cardsToNotes", cards=[id])
            for note_id in notes:
                update_note(note_id, idx, expression, sentence)
            IGNORE.add(id)
    finally:
        CHECK_LOCK.release()


TIME = 0, time.time()


def clock():
    return TIME[0] + min(time.time() - TIME[1], 1.0)


def find_sub(path):
    path = Path(path)
    dir = path.parent
    stem = path.stem

    return next(
        (
            f
            for f in dir.iterdir()
            if f.suffix in [".srt", ".ass"] and f.stem.startswith(stem)
        ),
        None,
    )


class Server(BaseHTTPRequestHandler):
    def do_GET(self):
        t = clock()

        if self.path in ["/", "/index.html"]:
            self.send_response(200)
            self.send_header("Content-type", "text/html; charset=utf-8")
            self.end_headers()

            with open(BASE / "index.html", "rb") as f:
                self.wfile.write(f.read())
        elif self.path == "/lines":
            self.send_response(200)
            self.send_header("Content-type", "text/json; charset=utf-8")
            self.end_headers()

            self.wfile.write(json.dumps({"id": ID, "lines": LINES}).encode())
        elif self.path == "/options":
            self.send_response(200)
            self.send_header("Content-type", "text/json; charset=utf-8")
            self.end_headers()

            self.wfile.write(json.dumps(OPTIONS).encode())
        elif self.path == "/update":
            self.send_response(200)
            self.send_header("Content-type", "text/json")
            self.end_headers()

            self.wfile.write(json.dumps([ID, to_ms(s=t)]).encode())
        else:
            self.send_response(404)
            self.end_headers()

    def do_POST(self):
        global OPTIONS, TIME, ID, FILE, DELAY, AID

        sz = int(self.headers.get("Content-Length"))
        if sz:
            raw_body = self.rfile.read(sz)
            try:
                body = json.loads(raw_body)
            except UnicodeDecodeError:
                try:
                    # Try CP932 (Shift-JIS) which is common for Japanese Windows and uses 0x82
                    body = json.loads(raw_body.decode("cp932"))
                except Exception:
                    # Last resort: ignore errors to prevent crash
                    body = json.loads(raw_body.decode("utf-8", "ignore"))
        else:
            body = {}

        t = clock()

        if self.path == "/init":
            self.send_response(200)
            self.end_headers()

            video_path = ""
            sub_content = None

            if isinstance(body, str):
                video_path = body
                sub_file = find_sub(video_path)
                if sub_file:
                    with open(sub_file, "r", encoding="utf-8") as f:
                        sub_content = f.read()
            elif isinstance(body, dict):
                video_path = body.get("video", "")
                sub_info = body.get("sub")

                if sub_info:
                    if sub_info.get("type") == "external":
                        path = sub_info.get("path")
                        if path and os.path.exists(path):
                            try:
                                with open(path, "r", encoding="utf-8") as f:
                                    sub_content = f.read()
                            except Exception as e:
                                print(f"Error reading subtitle file: {e}")
                    elif sub_info.get("type") == "internal":
                        idx = sub_info.get("index")
                        codec = sub_info.get("codec", "")
                        fmt = "ass" if codec in ["ass", "ssa"] else "srt"
                        if idx is not None:
                            sub_content = extract_internal_subs(video_path, idx, fmt)

            FILE = video_path
            AID = body.get("aid") if isinstance(body, dict) else None
            load_subs_content(sub_content)
        elif self.path == "/aid":
            self.send_response(200)
            self.end_headers()

            AID = body.get("aid") if isinstance(body, dict) else None
        elif self.path == "/update":
            self.send_response(200)
            self.end_headers()

            TIME = body.get("time"), time.time()
            DELAY = body.get("delay")
        elif self.path == "/check":
            self.send_response(200)
            self.end_headers()

            check(t)
        elif self.path == "/options":
            self.send_response(200)
            self.end_headers()

            if isinstance(body, dict):
                OPTIONS.update(body)
                try:
                    with open(OPTIONS_PATH, "w", encoding="utf-8") as f:
                        json.dump(OPTIONS, f, indent=2, ensure_ascii=False)
                except Exception as e:
                    print(f"Error writing options: {e}")
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, format, *args):
        _ = format
        _ = args


if __name__ == "__main__":
    with ThreadingHTTPServer(("127.0.0.1", 6969), Server) as server:
        server.serve_forever()
