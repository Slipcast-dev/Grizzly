(async function boot() {
  const info = await window.api.info();
  setLocale(info.locale);
  languagePref = info.language;
  Prefs.load();
  applyTheme();
  await Library.load(info.platform === 'win32');

  initUpdates(info.version);
  buildUI();
  App.render(['all']);
  App.startWatching();

  window.api.onMenu(runCommand);
  window.api.onOpenFiles((paths) => App.open(paths));
  window.api.ready();
  // Every launch asks GitHub whether a newer version is out; the answer appears only if there is one.
  checkForUpdates(true);
})();
