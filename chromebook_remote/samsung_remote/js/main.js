

(function()
{
  var connectionId;
  var ch2_1 = document.querySelector(".ch2_1");
  var ch2_2 = document.querySelector(".ch2_2");
  var ch4_1 = document.querySelector(".ch4_1");
  var ch4_2 = document.querySelector(".ch4_2");
  var ch5_1 = document.querySelector(".ch5_1");
  var ch9_1 = document.querySelector(".ch9_1");
  var ch9_2 = document.querySelector(".ch9_2");
  var ch9_3 = document.querySelector(".ch9_3");
  var ch9_4 = document.querySelector(".ch9_4");
  var ch11_1 = document.querySelector(".ch11_1");
  var ch11_2 = document.querySelector(".ch11_2");
  var ch30_1 = document.querySelector(".ch30_1");
  var ch46_1 = document.querySelector(".ch46_1");

  var onClickChan = function(chan)
  {
    console.log(chan);
    send(chan);
  }

  var str2ab = function(str)
  {
    var buf = new ArrayBuffer(str.length);
    var buf_vew = new Uint8Array(buf);

    console.log("Sending " + str);

    for (var i = 0; i < str.length; i++)
    {
      buf_vew[i] = str.charCodeAt(i);
    }

    return buf;
  }

  var send = function(s)
  {
    chrome.serial.write(connectionId, str2ab(s), onWrite);
    chrome.serial.flush(connectionId, onFlush);
  }

  var onOpen = function(connectionInfo)
  {
    connectionId = connectionInfo.connectionId;
    //chrome.serial.write(connectionId, str2ab("your momma\r\n"), onWrite);
    //chrome.serial.flush(connectionId, onFlush);
  }

  var onWrite = function(write_info)
  {
    console.log("Written");
  }

  var onFlush = function(result)
  {
    console.log("Flush");
  }

  var onGetPorts = function(ports)
  {
    for (var i = 0; i < ports.length; i++)
    {
      console.log(ports[i]);
      if (ports[i].search("USB")>=0)
      {
        console.log("Connecting " + ports[i]);
        chrome.serial.open(ports[i], { bitrate: 9600 }, onOpen);
      }
    }
  }

  var init = function()
  {
    chrome.serial.getPorts(onGetPorts);
    ch2_1.addEventListener("click", function() { onClickChan("2-1"); });
    ch2_2.addEventListener("click", function() { onClickChan("2-2"); });
    ch4_1.addEventListener("click", function() { onClickChan("4"); });
    ch4_2.addEventListener("click", function() { onClickChan("4-2"); });
    ch5_1.addEventListener("click", function() { onClickChan("5"); });
    ch9_1.addEventListener("click", function() { onClickChan("9"); });
    ch9_2.addEventListener("click", function() { onClickChan("9-2"); });
    ch9_3.addEventListener("click", function() { onClickChan("9-3"); });
    ch9_4.addEventListener("click", function() { onClickChan("9-4"); });
    ch11_1.addEventListener("click", function() { onClickChan("11"); });
    ch11_2.addEventListener("click", function() { onClickChan("11-2"); });
    ch30_1.addEventListener("click", function() { onClickChan("30"); });
    ch46_1.addEventListener("click", function() { onClickChan("46"); });
  }

  init(); 

})();

