document.querySelectorAll('button[data-copy]').forEach(function (button) {
  var label = button.getAttribute('aria-label') || button.textContent;
  var status = button.parentElement.querySelector('[role="status"]');
  var timer;
  var icon = !!button.querySelector('svg');
  function feedback(text, state) {
    clearTimeout(timer);
    button.dataset.state = state;
    button.setAttribute('aria-label', text);
    button.title = text;
    if (!icon) button.textContent = text;
    if (status) status.textContent = text;
    timer = setTimeout(function () {
      delete button.dataset.state;
      button.setAttribute('aria-label', label);
      button.title = label;
      if (!icon) button.textContent = label;
      if (status) status.textContent = '';
    }, 1800);
  }
  button.addEventListener('click', function () {
    var target = document.getElementById(button.dataset.copy);
    var text = target.textContent;
    var selected = function () {
      var range = document.createRange();
      range.selectNodeContents(target);
      var selection = getSelection();
      selection.removeAllRanges();
      selection.addRange(range);
      feedback(button.dataset.fallback || label, 'selected');
    };
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text).then(function () {
        feedback(button.dataset.done, 'copied');
      }, selected);
    } else selected();
  });
});
