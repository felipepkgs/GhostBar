const bars = document.querySelectorAll(".bar");

// Rebuilds the Control Strip row from the user's real, live customization —
// pushed from Swift (ControlStripReader) right before each fade-in.
window.setControlStrip = function (items) {
  const bar = document.getElementById("barControl");
  const dot = bar.querySelector(".dot");
  bar.querySelectorAll(".group, .spacer").forEach((el) => el.remove());

  items.forEach((item) => {
    if (item.kind === "space") {
      const spacer = document.createElement("div");
      spacer.className = "spacer";
      bar.insertBefore(spacer, dot);
      return;
    }
    const group = document.createElement("div");
    group.className = "group";
    group.style.flex = String(item.icons.length);
    item.icons.forEach((icon) => {
      const seg = document.createElement("div");
      seg.className = "seg";
      if (icon.type === "image" || icon.type === "image-small") {
        const img = document.createElement("img");
        img.className = icon.type === "image-small" ? "icon-img small" : "icon-img";
        img.src = "icons/" + icon.value;
        seg.appendChild(img);
      } else {
        seg.textContent = icon.value;
      }
      group.appendChild(seg);
    });
    bar.insertBefore(group, dot);
  });
};

// Hides whichever row ISN'T the Touch Bar's actual current mode for the
// frontmost app, instead of always presenting both as equally plausible.
window.setMode = function (mode) {
  const fKeysRow = document.getElementById("barFKeys").closest(".row");
  const controlRow = document.getElementById("barControl").closest(".row");
  fKeysRow.classList.toggle("hidden", mode !== "functionKeys");
  controlRow.classList.toggle("hidden", mode !== "controlStrip");
};

// Preferences' "Theme" picker — see style.css's body[data-theme="..."]
// blocks for what each one actually changes.
window.setTheme = function (theme) {
  document.body.dataset.theme = theme;
};

// Preferences' "Touch Feedback" section — style picker, "Flash touched
// segment" toggle, and the feedback color. Pushed on every show (see
// OverlayPanelController.refreshLiveLayout) and live while Preview is open
// (see defaultsChanged), same pattern as setTheme.
let touchFeedbackStyle = "none";
let flashTouchedSegmentEnabled = false;
window.setTouchFeedback = function (style, flashSegmentEnabled, colorHex) {
  touchFeedbackStyle = style || "none";
  flashTouchedSegmentEnabled = !!flashSegmentEnabled;
  if (colorHex) document.documentElement.style.setProperty("--touch-feedback-color", colorHex);
};

let wasTouchActive = false;

window.onTouchPosition = function (data) {
  const active = !!(data && data.active);
  const justTouchedDown = active && !wasTouchActive;
  wasTouchActive = active;

  bars.forEach((bar) => {
    const dot = bar.querySelector(".dot");
    if (!active) {
      dot.style.opacity = "0";
      clearActiveSeg(bar);
      return;
    }
    dot.style.opacity = "1";
    dot.style.left = (data.x * 100) + "%";
    const matchedSeg = highlightSeg(bar, data.x);
    if (justTouchedDown) {
      spawnTouchFx(bar, data.x);
      if (flashTouchedSegmentEnabled && matchedSeg) flashSegment(matchedSeg);
    }
  });
};

// Fires once per touch-down (see justTouchedDown above), not continuously —
// these are one-shot transients, not something that tracks the finger.
// press-bounce animates .dot itself instead of spawning an element; sonar
// spawns three staggered rings (see style.css's .fx-sonar-N delays);
// everything else spawns one .touch-fx element, self-removing via
// animationend so the DOM doesn't accumulate stale nodes across taps.
function spawnTouchFx(bar, fraction) {
  if (touchFeedbackStyle === "none") return;
  const dot = bar.querySelector(".dot");

  if (touchFeedbackStyle === "pressBounce") {
    dot.classList.remove("fx-press-bounce");
    void dot.offsetWidth; // restart the animation on a re-tap before the last one finished
    dot.classList.add("fx-press-bounce");
    return;
  }

  const leftPct = fraction * 100;

  if (touchFeedbackStyle === "sonar") {
    [1, 2, 3].forEach((i) => {
      const el = document.createElement("div");
      el.className = "touch-fx fx-sonar fx-sonar-" + i;
      el.style.left = leftPct + "%";
      bar.appendChild(el);
      el.addEventListener("animationend", () => el.remove());
    });
    return;
  }

  const classMap = { ripple: "fx-ripple", radialFill: "fx-radial-fill", flashBurst: "fx-flash-burst" };
  const cls = classMap[touchFeedbackStyle];
  if (!cls) return;
  const el = document.createElement("div");
  el.className = "touch-fx " + cls;
  el.style.left = leftPct + "%";
  bar.appendChild(el);
  el.addEventListener("animationend", () => el.remove());
}

function flashSegment(seg) {
  seg.classList.remove("seg-flash");
  void seg.offsetWidth;
  seg.classList.add("seg-flash");
  seg.addEventListener("animationend", () => seg.classList.remove("seg-flash"), { once: true });
}

// Lights up whichever segment the dot currently sits over, on both rows at
// once — cheap "touch feedback" that goes a long way toward feeling like a
// real display instead of a static reference chart. Returns the matched
// segment (or null) so callers can layer the one-shot flash effect on it.
function highlightSeg(bar, fraction) {
  const rect = bar.getBoundingClientRect();
  const pointerX = rect.left + fraction * rect.width;
  let match = null;
  bar.querySelectorAll(".seg").forEach((seg) => {
    const segRect = seg.getBoundingClientRect();
    if (pointerX >= segRect.left && pointerX <= segRect.right) match = seg;
  });
  bar.querySelectorAll(".seg.active-seg").forEach((seg) => {
    if (seg !== match) seg.classList.remove("active-seg");
  });
  if (match) match.classList.add("active-seg");
  return match;
}

// Answers "is this touch position over Volume Up/Down/Mute" — those have
// their own system sound when pressed, so Swift's touch-sound feature (see
// OverlayPanelController.maybeScheduleTouchSound) skips playing on top of
// it. Deterministic instead of guessing from event timing (tried that
// three times, on the Swift side, racing sendAction's arrival against a
// fixed delay — never reliably worked, since it depends on how long the OS
// itself takes to report the action back, which varies). This runs the
// exact same hit-test highlightSeg already uses for the visible highlight,
// against whichever row is actually showing, then checks the matched
// segment's own icon filename — volume-up.png/volume-down.png/
// volume-mute.png all contain "volume".
window.isTouchOverOwnSoundControl = function (fraction) {
  const activeBar = document.querySelector(".row:not(.hidden) .bar");
  if (!activeBar) return false;
  const rect = activeBar.getBoundingClientRect();
  const pointerX = rect.left + fraction * rect.width;
  let match = null;
  activeBar.querySelectorAll(".seg").forEach((seg) => {
    const segRect = seg.getBoundingClientRect();
    if (pointerX >= segRect.left && pointerX <= segRect.right) match = seg;
  });
  const img = match && match.querySelector(".icon-img");
  return !!(img && /volume/i.test(img.getAttribute("src") || ""));
};

function clearActiveSeg(bar) {
  bar.querySelectorAll(".seg.active-seg").forEach((seg) => seg.classList.remove("active-seg"));
}

const actionIcons = {
  "Volume Up": "🔊", "Volume Down": "🔉", "Mute": "🔇",
  "Brightness Up": "🔆", "Brightness Down": "🔅",
  "Play / Pause": "⏯", "Next": "⏭", "Previous": "⏮",
  "Fast Forward": "⏩", "Rewind": "⏪", "Eject": "⏏",
  "Keyboard Brightness Up": "⌨️", "Keyboard Brightness Down": "⌨️",
  "Keyboard Brightness Toggle": "⌨️",
};

let actionHideTimer = null;

window.onAction = function (label) {
  const el = document.getElementById("action");
  const icon = actionIcons[label] || "•";
  el.innerHTML = `<div class="pill"><span class="icon">${icon}</span><span class="label">${label}</span></div>`;
  el.classList.add("visible");
  clearTimeout(actionHideTimer);
  actionHideTimer = setTimeout(() => el.classList.remove("visible"), 2000);
};
