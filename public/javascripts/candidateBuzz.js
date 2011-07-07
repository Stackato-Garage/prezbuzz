/*
 * Copyright (c) 2011 ActiveState Software Inc.
 * See the file LICENSE.txt for licensing information.
 */

var payloadPatterns = /([@#])([A-Za-z]\w\w+)/;
var isCharPattern = /\w$/;
var tweetDump = null;
var tweetDumpList = null;
var wordCloudDiv = null;
var stuffContainer = null;

function initSidebar() {
    stuffContainer = document.getElementById("stuff-container");
    tweetDump = document.getElementById("buzz_tweets");
    tweetDumpList = document.getElementById("holder");
    wordCloudDiv = document.getElementById("word_cloud");
}

        
var h = function(s) {
  return s;
  //return s.replace(/\&/g, "&amp;").replace(/</g, "&lt;")
};

var processPayload = function(hParts, text) {
  var parts = text.split(payloadPatterns);
  var i = 0, term, len = parts.length, part;
  var skipPart = false;
  while (i < len - 1) {
    part = parts[i];
    if (skipPart) {
      hParts.push(part);
      skipPart = !isCharPattern.test(part);
    } else if (part == "@") {
      term = parts[i + 1];
      hParts.push('<a href="https://twitter.com/#!/');
      hParts.push(term);
      hParts.push('">@');
      hParts.push(term);
      hParts.push('</a>');
      skipPart = true;
      i += 1;
    } else if (part == "#") {
      term = parts[i + 1];
      hParts.push('<a href="https://twitter.com/#!/search/%23');
      hParts.push(term);
      hParts.push('">#');
      hParts.push(term);
      hParts.push('</a>');
      skipPart = true;
      i += 1;
    } else {
      hParts.push(part);
    }
    i += 1;
  }
  if (i == len - 1) {
    hParts.push(parts[i]);
  }
};


// Now setup the json tweet stuff
var getWordCloudCallback = function(json) {
    //alert("about to build cloud from " + json.length + " iterms")
    var wordCloudDiv = document.getElementById("word_cloud");
    $('#word_cloud').addClass('loading');
    while (wordCloudDiv.firstChild) {
        wordCloudDiv.removeChild(wordCloudDiv.firstChild);
    }
    $("#word_cloud").jQCloud(json);
    $("#word_cloud").removeClass('loading');
};

// Now setup the json tweet stuff
var getTweetCallback = function(json) {
  var outlet = document.getElementById("temp");
  var results = json;//jQuery.parseJSON(json);
  var numTweets = results.length;
  stuffContainer.style.display = "block";
  $('#holder').addClass('loading');
  while (tweetDumpList.firstChild) {
    tweetDumpList.removeChild(tweetDumpList.firstChild);
  }
  insertTweets(results, 0, numTweets);
};

function swGotoPage(page){
    console.log("page " + page);
    // don't even try when we're trying to hit page 0
    if( page == '0' ) { return; }
    
    if ( page == '1') {
        // disable the back link
        $('#twitter_controls #button_back').attr('disabled', 'disabled');
    }
    else {
        $('#twitter_controls #button_back').removeAttr('disabled');
    }
    var forwardIndex = page + 1;
    var forwardElem = ".swShowPage:contains('" + forwardIndex+ "')";
    if ($(forwardElem).length == 0) {
        $('#twitter_controls #button_forward').attr('disabled', 'disabled');
    }
    else {
        $('#twitter_controls #button_forward').removeAttr('disabled');
    }
    var elem = ".swShowPage:contains('" + page + "')";
    if ($(elem).length != 0 ) {
        $(elem)[0].click();
    }
}

function insertTweets(results, i, numTweets) {
    if (i >= numTweets) {
        
        // all tweets added, so run sweetpages
        $('#holder').sweetPages({perPage:3});
        $('#holder').removeClass('loading');
                
        var $pgBack = $('#twitter_controls #button_back');
        var $pgForward = $('#twitter_controls #button_forward');
        var active = '.swShowPage.active';
        var offset = 'pgOffset';
        
        $.each([$pgBack, $pgForward], function(i,$obj){
            console.log($obj);
            // unbind old click event handler
            $obj.unbind('click');
            
            // if there are 3 or fewer tweets, don't bother binding a click event to the buttons
            if (numTweets <= 3) {
                $obj.attr('disabled', 'disabled');
            }
            else {
                $obj.click(function(){
                    var nextPage =  parseInt($(active).text(), 10) + parseInt($(this).attr(offset), 10);
                    swGotoPage(nextPage);
                });
            }
        });
        
        // set the back button to disabled on load, since we'll be at the first page
        $('#twitter_controls #button_back').attr('disabled', 'disabled');
                
        return;
    }
    
    var result = results[i];
    var stuff, listitem;
    var hParts = [];
    hParts.push('<div class="tweetContainer">');
    var twitterLink = "http://twitter.com/" + result.name;
    if (result.img) {
      hParts.push('<div class="tweetUserImageContainer">');
      hParts.push('<a href="');
      hParts.push(twitterLink);
      hParts.push('"><img height="48" width="48" src="');
      hParts.push(result.img);
      hParts.push('" border="0"></a></div>\n');
    }
    hParts.push('<div class="tweetContentsContainer">');
    hParts.push('<div class="tweetUserNameContainer">');
    hParts.push('<a href="http://twitter.com/');
    hParts.push(result.name);
    hParts.push('">');
    hParts.push(result.name);
    hParts.push('</a>');
    hParts.push('</div>'); // tweetUserNameContainer
    hParts.push('<div class="tweetPayloadContainer">');
    processPayload(hParts, result.text);
    hParts.push('</div>'); // tweetPayloadContainer
    hParts.push('</div>'); // tweetContentsContainer
    hParts.push('</div>'); // tweetContainer
    if (i < numTweets - 1) {
      hParts.push("<hr >");
    }
    stuff = hParts.join("\n");
    listitem = document.createElement("li");
    listitem.innerHTML = stuff;
    tweetDumpList.appendChild(listitem);
    setTimeout(insertTweets, 50, results, i + 1, numTweets);
    // yellow fade would be nice here....
}
