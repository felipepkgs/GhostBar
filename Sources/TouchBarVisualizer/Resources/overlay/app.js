const dots = document.querySelectorAll(".dot");

window.onTouchPosition = function (data) {
  dots.forEach((dot) => {
    if (!data || !data.active) {
      dot.style.opacity = "0";
      return;
    }
    dot.style.opacity = "1";
    dot.style.left = (data.x * 100) + "%";
  });
};

let actionHideTimer = null;

window.onAction = function (label) {
  const el = document.getElementById("action");
  el.textContent = label;
  el.classList.add("visible");
  clearTimeout(actionHideTimer);
  actionHideTimer = setTimeout(() => el.classList.remove("visible"), 2000);
};
