chrome.app.runtime.onLaunched.addListener(function()
{
  chrome.app.window.create('window.html',
  {
    frame: "custom",
    bounds: { width: 650, height:350 }
  });
});


