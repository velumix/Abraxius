const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const appDirectory = path.join(__dirname, "..", "app", "Abraxius.App");
const source = fs.readFileSync(path.join(appDirectory, "MainWindow.xaml.cs"), "utf8");
const xaml = fs.readFileSync(path.join(appDirectory, "MainWindow.xaml"), "utf8");

test("Change Review is the guarded editor mutation path", () => {
  assert.match(xaml, /x:Name="ReviewPage"/);
  assert.match(xaml, /Text="Review change"/);
  assert.match(xaml, /Text="Apply selected"/);

  const stageStart = source.indexOf("private async void PushEditorChangesButton_Click");
  const stageEnd = source.indexOf("private async void RefreshChangeReviewButton_Click", stageStart);
  const stage = source.slice(stageStart, stageEnd);
  assert.match(stage, /PreviewEditorChangesAsync/);
  assert.match(stage, /CategoryNavigation\.SelectedItem = ReviewNavigationItem/);
  assert.doesNotMatch(stage, /\["dryRun"\] = false/);

  const selectStart = source.indexOf("private async void ChangeReviewList_SelectionChanged");
  const selectEnd = source.indexOf("private void ResetChangeReviewDetails", selectStart);
  const preflight = source.slice(selectStart, selectEnd);
  assert.match(preflight, /\["dryRun"\] = true/);
  assert.match(preflight, /ApplyReviewedChangeButton\.IsEnabled = true/);
});

test("Change Review confirms applies and keeps conflict-checked rollback state", () => {
  const applyStart = source.indexOf("private async void ApplyReviewedChangeButton_Click");
  const applyEnd = source.indexOf("private async Task ApplyCommandReviewAsync", applyStart);
  const apply = source.slice(applyStart, applyEnd);
  assert.match(apply, /dialog\.ShowAsync\(\) != ContentDialogResult\.Primary/);
  assert.match(apply, /\["expectedHash"\] = item\.ExpectedHash/);
  assert.match(apply, /Studio read-back did not match the approved source/);
  assert.match(apply, /new EditorRollback\(item\.Target, beforeSource/);

  const rollbackStart = source.indexOf("private async void RollbackLastChangeButton_Click");
  const rollbackEnd = source.indexOf("private static string EstimateSourceRisk", rollbackStart);
  const rollback = source.slice(rollbackStart, rollbackEnd);
  assert.match(rollback, /\["expectedHash"\] = rollback\.AppliedHash/);
  assert.match(rollback, /Rollback read-back did not match the previous source/);
});

test("Studio commands are not constrained by the one-second health timeout", () => {
  assert.match(source, /_http = new\(\) \{ BaseAddress = ApiBase, Timeout = TimeSpan\.FromSeconds\(1\) \}/);
  assert.match(source, /_studioHttp = new\(\) \{ BaseAddress = ApiBase, Timeout = TimeSpan\.FromSeconds\(35\) \}/);

  const callStart = source.indexOf("private async Task<JsonElement> CallPluginAsync");
  const callEnd = source.indexOf("private static string? FindJsonString", callStart);
  const commandTransport = source.slice(callStart, callEnd);
  assert.match(commandTransport, /_studioHttp\.PostAsJsonAsync\("plugin\/call"/);
  assert.match(commandTransport, /_studioHttp\.PostAsJsonAsync\("call"/);
  assert.doesNotMatch(commandTransport, /_http\.PostAsJsonAsync/);

  const discoveryStart = source.indexOf("private async Task DiscoverCommandsAsync");
  const discoveryEnd = source.indexOf("private static JsonElement? FindCommandsElement", discoveryStart);
  assert.match(source.slice(discoveryStart, discoveryEnd), /_studioHttp\.PostAsJsonAsync/);
});

test("Commands uses task-first progressive disclosure and routes queued work to Review", () => {
  assert.match(xaml, /Text="What do you want to do\?"/);
  assert.match(xaml, /Tag="create_script" Click="CommandShortcutButton_Click"/);
  assert.match(xaml, /Header="Advanced JSON and schema" IsExpanded="False"/);
  assert.match(xaml, /Text="Add to Change Review"/);
  assert.match(xaml, /Click="OpenChangeReviewQueueButton_Click"/);
  assert.doesNotMatch(xaml, /Click="ExecuteApprovalQueueButton_Click"[^>]*Content="Review and execute queue"/);
  assert.match(source, /ApprovalQueueEmptyState\.Visibility/);
  assert.match(source, /RunCommandButton\.IsEnabled = command is not null && !mutating/);
  assert.match(source, /CommandPicker\.SelectedItem = "get_selection"/);
});
