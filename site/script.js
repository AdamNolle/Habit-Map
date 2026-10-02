const patterns = [
  [0,2,3,5,7,8,10,11,12,14,15,16,18,20,21,22,23,25,26],
  [1,2,4,6,7,9,10,12,13,15,17,18,19,21,22,24,26,27]
];

function fillGrid(container, rows, cols, pattern) {
  if (!container) return;
  const fragment = document.createDocumentFragment();
  for (let row = 0; row < rows; row++) {
    for (let col = 0; col < cols; col++) {
      const cell = document.createElement('span');
      const day = (col * rows + row) % 28;
      cell.className = pattern.includes(day) ? 'cell is-filled' : 'cell';
      if ((col * rows + row) % 11 === 0 && pattern.includes(day)) cell.classList.add('is-bright');
      fragment.append(cell);
    }
  }
  container.append(fragment);
}

fillGrid(document.getElementById('atlas-grid'), 7, 12, patterns[0]);
fillGrid(document.getElementById('map-demo'), 7, 24, patterns[1]);
