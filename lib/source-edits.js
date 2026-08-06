function splitLines(source) {
  if (source === "") return [];
  return source.match(/.*?(?:\r\n|\n|\r|$)/g).filter(Boolean);
}

function normalizeSource(source) {
  return String(source).replace(/\r\n?/g, "\n");
}

function countOccurrences(source, needle) {
  if (needle === "") return 0;
  let count = 0;
  let offset = 0;
  while ((offset = source.indexOf(needle, offset)) !== -1) {
    count += 1;
    offset += Math.max(needle.length, 1);
  }
  return count;
}

function replaceLiteral(source, oldString, newString) {
  const index = source.indexOf(oldString);
  if (index === -1) return source;
  return source.slice(0, index) + newString + source.slice(index + oldString.length);
}

function findResync(oldLines, newLines, oldStart, newStart) {
  const newPositions = new Map();
  for (let index = newStart; index < newLines.length; index += 1) {
    const positions = newPositions.get(newLines[index]) || [];
    positions.push(index);
    newPositions.set(newLines[index], positions);
  }

  let best = null;
  for (let oldIndex = oldStart; oldIndex < oldLines.length; oldIndex += 1) {
    const positions = newPositions.get(oldLines[oldIndex]);
    if (!positions) continue;
    for (const newIndex of positions) {
      const distance = oldIndex - oldStart + newIndex - newStart;
      if (!best || distance < best.distance) {
        best = { oldIndex, newIndex, distance };
      }
      break;
    }
    if (best && oldIndex - oldStart > best.distance) break;
  }
  return best;
}

function findHunks(oldSource, newSource) {
  const oldLines = splitLines(oldSource);
  const newLines = splitLines(newSource);
  const hunks = [];
  let oldIndex = 0;
  let newIndex = 0;

  while (oldIndex < oldLines.length || newIndex < newLines.length) {
    if (oldLines[oldIndex] === newLines[newIndex]) {
      oldIndex += 1;
      newIndex += 1;
      continue;
    }

    const startOld = oldIndex;
    const startNew = newIndex;
    const resync = findResync(oldLines, newLines, oldIndex, newIndex);
    if (resync) {
      oldIndex = resync.oldIndex;
      newIndex = resync.newIndex;
    } else {
      oldIndex = oldLines.length;
      newIndex = newLines.length;
    }
    hunks.push({ startOld, endOld: oldIndex, startNew, endNew: newIndex });
  }

  return { oldLines, newLines, hunks };
}

function buildCoalescedEdit(oldSource, newSource) {
  let oldStart = 0;
  let newStart = 0;
  while (
    oldStart < oldSource.length &&
    newStart < newSource.length &&
    oldSource[oldStart] === newSource[newStart]
  ) {
    oldStart += 1;
    newStart += 1;
  }

  let oldEnd = oldSource.length;
  let newEnd = newSource.length;
  while (oldEnd > oldStart && newEnd > newStart && oldSource[oldEnd - 1] === newSource[newEnd - 1]) {
    oldEnd -= 1;
    newEnd -= 1;
  }

  let oldString = oldSource.slice(oldStart, oldEnd);
  let newString = newSource.slice(newStart, newEnd);

  while (oldString === "" || countOccurrences(oldSource, oldString) !== 1) {
    if (oldStart > 0 && newStart > 0 && oldSource[oldStart - 1] === newSource[newStart - 1]) {
      oldStart -= 1;
      newStart -= 1;
    } else if (
      oldEnd < oldSource.length &&
      newEnd < newSource.length &&
      oldSource[oldEnd] === newSource[newEnd]
    ) {
      oldEnd += 1;
      newEnd += 1;
    } else {
      throw new Error("Could not coalesce generated edits into unique unchanged context");
    }
    oldString = oldSource.slice(oldStart, oldEnd);
    newString = newSource.slice(newStart, newEnd);
  }

  if (oldStart === 0 && oldEnd === oldSource.length) {
    throw new Error("No shared source context exists for a safe granular multi_edit");
  }
  if (replaceLiteral(oldSource, oldString, newString) !== newSource) {
    throw new Error("Coalesced multi_edit did not reproduce the requested source");
  }
  return { old_string: oldString, new_string: newString };
}

function buildSourceEdits(oldSource, newSource) {
  oldSource = normalizeSource(oldSource);
  newSource = normalizeSource(newSource);

  if (oldSource === newSource) return [];
  if (oldSource === "") {
    throw new Error("Cannot safely multi-edit an existing empty script without replacing its whole source");
  }

  const { oldLines, newLines, hunks } = findHunks(oldSource, newSource);
  if (hunks.length === 1 && hunks[0].startOld === 0 && hunks[0].endOld === oldLines.length) {
    throw new Error("No shared source context exists for a safe granular multi_edit");
  }

  let simulated = oldSource;
  const edits = [];
  let hunkIndex = hunks.length - 1;
  while (hunkIndex >= 0) {
    const hunk = hunks[hunkIndex];
    let oldStart = hunk.startOld;
    let oldEnd = hunk.endOld;
    let newStart = hunk.startNew;
    let newEnd = hunk.endNew;
    let oldString = oldLines.slice(oldStart, oldEnd).join("");
    let newString = newLines.slice(newStart, newEnd).join("");

    while (oldString === "" || countOccurrences(simulated, oldString) !== 1) {
      if (oldStart > 0 && newStart > 0 && oldLines[oldStart - 1] === newLines[newStart - 1]) {
        oldStart -= 1;
        newStart -= 1;
      } else if (
        oldEnd < oldLines.length &&
        newEnd < newLines.length &&
        oldLines[oldEnd] === newLines[newEnd]
      ) {
        oldEnd += 1;
        newEnd += 1;
      } else if (hunkIndex > 0) {
        // A repeated changed block can exhaust the unchanged lines around it
        // before becoming unique. Coalesce it with the preceding change and
        // the shared lines between them instead of rejecting a safe push.
        hunkIndex -= 1;
        oldStart = hunks[hunkIndex].startOld;
        newStart = hunks[hunkIndex].startNew;
      } else {
        throw new Error("Could not find unique unchanged context for a safe granular multi_edit");
      }
      oldString = oldLines.slice(oldStart, oldEnd).join("");
      newString = newLines.slice(newStart, newEnd).join("");
    }

    simulated = replaceLiteral(simulated, oldString, newString);
    edits.push({ old_string: oldString, new_string: newString });
    hunkIndex -= 1;
  }

  if (simulated !== newSource) {
    return [buildCoalescedEdit(oldSource, newSource)];
  }
  return edits;
}

module.exports = { buildSourceEdits, normalizeSource };
