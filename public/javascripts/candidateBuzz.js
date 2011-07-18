/*
 * Copyright (c) 2011 ActiveState Software Inc.
 * See the file LICENSE.txt for licensing information.
 */

var payloadPatterns = /([@#])([A-Za-z]\w\w+)/;
var isCharPattern = /\w$/;
var tweetDump = null;
var tweetDumpList = null;
var wordCloudDiv = null;
var searchTextField = null;
var paginator_list;
//var stuffContainer = null;

var storedTweets = null;
var storedFilteredTweets = null;
var numTweetsPerBlock = 20;

var buzz_tweet_paginator_box = null;

var textChangedHandlerId = 0;
var textChangedDelay = 1000; // msec

function addSearchFieldListener() {
//alert("About to add an event listner");
    try {
      searchTextField.addEventListener("keypress", tweetLineupUpdateSearch, false);
    } catch(ex) {
/*
  alert("failed to listen: " + ex);
  var s = [];
  for (var p in ex) {
  try {
  var o = ex[p];
  if (typeof(o) != "function") s.push(p + ":" + o);
  } catch(ex2) {}
  }
  alert("more details:\n" + s.join("\n"));
*/
        try {
            searchTextField.onchange = tweetLineupUpdateSearch;
            if (searchTextField.parentNode.childNodes.length == 1) {
                var searchButton = document.createElement("input");
                searchButton.setAttribute("type", "button");
                searchButton.setAttribute("label", "Search");
                searchButton.setAttribute("oncommand", "tweetLineupUpdateSearch(event);");
                alert("Go add a search node....");
                searchTextField.parentNode.appendChild(searchButton);
            }
        } catch(ex) {
            alert("Sorry, searching doesn't work on this web browser");
        }
    }
}

function initSidebar() {
    //stuffContainer = document.getElementById("stuff-container");
    paginator_list =  document.getElementById('paginator_list');
    tweetDump = document.getElementById("buzz_tweets");
    tweetDumpList = document.getElementById("holder");
    wordCloudDiv = document.getElementById("word_cloud");
    searchTextField = document.getElementById("buzz_tweet_search");
    addSearchFieldListener();
}

function doTextChange() {
    if (textChangedHandlerId) {
        clearTimeout(textChangedHandlerId);
        textChangedHandlerId = 0;
    }
    var field = searchTextField.value.replace(/^\s*/, "").replace(/\s*$/, "");
    if (!field) {
        storedFilteredTweets = storedTweets;
    } else {
        storedFilteredTweets = filterTweets(storedTweets, field);
        if (storedFilteredTweets.length === 0) {
            //alert("No items returned, not changing anything");
            storedFilteredTweets = storedTweets;
            return;
        }
    }
    var numTweets = storedFilteredTweets.length;
    clearTweetList();
    var stopIndex = numTweetsPerBlock;
    if (numTweets > stopIndex) {
        buzz_tweet_paginator_box.setAttribute("class", "show");
        updatePaginator(numTweets, 0);
    } else {
        stopIndex = numTweets;
        buzz_tweet_paginator_box.setAttribute("class", "hide");
    }
    insertTweets(storedFilteredTweets, 0, stopIndex);
}

function filterTweets(tweets, searchText) {
    var i, tweet, newTweets = [];
    var ptn = new RegExp(searchText, "i");
    for (i = 0; (tweet = tweets[i]); i++) {
        if (ptn.test(tweet.name) || ptn.test(tweet.text)) {
            newTweets.push(tweet);
        }
    }
    return newTweets;
}

function tweetLineupUpdateSearch(event) {
    //alert("tweetLineupUpdateSearch")
    if (textChangedHandlerId) {
        clearTimeout(textChangedHandlerId);
    }
    textChangedHandlerId = setTimeout(doTextChange, textChangedDelay);
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
      hParts.push('" target="_blank">@');
      hParts.push(term);
      hParts.push('</a>');
      skipPart = true;
      i += 1;
    } else if (part == "#") {
      term = parts[i + 1];
      hParts.push('<a href="https://twitter.com/#!/search/%23');
      hParts.push(term);
      hParts.push('" target="_blank">#');
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
    var wordCloudDiv = document.getElementById("word_cloud");
    while (wordCloudDiv.firstChild) {
        wordCloudDiv.removeChild(wordCloudDiv.firstChild);
    }
    $("#word_cloud").jQCloud(json);
};

// Now setup the json tweet stuff
var getTweetCallback = function(json) {
  var results = json;
  var numTweets = results.length;
  if (!buzz_tweet_paginator_box) {
    buzz_tweet_paginator_box = document.getElementById('buzz_tweet_paginator_box');
  }
  clearTweetList();
  storedFilteredTweets = storedTweets = [].concat(results); // shallow copy
  var stopIndex = numTweetsPerBlock;
  if (numTweets > stopIndex) {
      buzz_tweet_paginator_box.setAttribute("class", "show");
      updatePaginator(numTweets, 0);
  } else {
      stopIndex = numTweets;
      buzz_tweet_paginator_box.setAttribute("class", "hide");
  }
  insertTweets(storedFilteredTweets, 0, stopIndex);
};

function clearTweetList() {
    paginator_list.innerHTML = "";
    while (tweetDumpList.firstChild) {
        tweetDumpList.removeChild(tweetDumpList.firstChild);
    }
}

function stopEvent(event) {
  try {
    event.stopPropagation();
    event.preventDefault();
  } catch(ex) {
    // There always has to be one... IE
    event.cancelBubble = true;
  }
}

function nextBlock(event, idx) {
    clearTweetList();
    if (idx == -1) {
        // Show all of them
        var numTweets = storedFilteredTweets.length;
        showRepagination(numTweets);
        stopEvent(event);
        insertTweets(storedFilteredTweets, 0, numTweets);
        return;
    }
    var startIndex = idx * numTweetsPerBlock;
    var stopIndex = startIndex + numTweetsPerBlock;
    var numTweets = storedFilteredTweets.length;
    updatePaginator(numTweets, idx);
    if (stopIndex > numTweets) {
        stopIndex = numTweets;
    }
    stopEvent(event);
    //alert("Insert " + numTweets + " from idx " + startIndex + " - " + stopIndex);
    insertTweets(storedFilteredTweets, startIndex, stopIndex);
}

function showRepagination(numTweets) {
    var numBlocks = Math.floor(numTweets / numTweetsPerBlock);
    var remainder = numTweets % numTweetsPerBlock;
    if (remainder > 0) numBlocks++;
    var linkTextParts = [], text;
    text = "Show All";
    linkTextParts.push(text);
    if (numBlocks > 5) {
        text = "<a href='#' onclick='nextBlock(event, 0); return 0;' >1</a>";
        linkTextParts.push(text);
        text = "<a href='#' onclick='nextBlock(event, 1); return 0;' >2</a>";
        linkTextParts.push(text);
        linkTextParts.push("...");
        text = "<a href='#' onclick='nextBlock(event, numBlocks - 2); return 0;' >" + (numBlocks - 1) + "</a>";
        linkTextParts.push(text);
        text = "<a href='#' onclick='nextBlock(event, numBlocks - 1); return 0;' >" + numBlocks + "</a>";
        linkTextParts.push(text);
    } else {
        for (var i = 0; i < numBlocks; i++) {
            text = "<a href='#' onclick='nextBlock(event, " + i + "); return 0;' >" + (i + 1) + "</a>";
            linkTextParts.push(text);
        }
    }
    //paginator_list.innerHTML = "<p>" + linkTextParts.join("") + "</p>";
    paginator_list.innerHTML = linkTextParts.join(" | ");
}

function updatePaginator(numTweets, idx) {
    var numBlocks = Math.floor(numTweets / numTweetsPerBlock);
    var remainder = numTweets % numTweetsPerBlock;
    if (remainder > 0) numBlocks++;
    var linkTextParts = [], text;
    text = "<a href='#' onclick='nextBlock(event, -1); return 0;' >All</a>";
    linkTextParts.push(text);
    if (idx === 0) {
        text = "&laquo; Prev";
    } else {
        text = "<a href='#' onclick='nextBlock(event, " + (idx - 1) + "); return 0;' >&laquo; Prev</a>";
    }
    linkTextParts.push(text);
    text = "Page " + (idx + 1) + " of " + numBlocks;
    linkTextParts.push(text);
    if (idx === numBlocks - 1) {
        text = "Next &raquo;";
    } else {
        text = "<a href='#' onclick='nextBlock(event, " + (idx + 1) + "); return 0;' >Next &raquo;</a>";
    }
    linkTextParts.push(text);
    //paginator_list.innerHTML = "<p>" + linkTextParts.join("") + "</p>";
    paginator_list.innerHTML = linkTextParts.join(" | ");
}

function insertTweets(results, i, numTweets) {
    if (i >= numTweets) {
        //XXX: Update the scroll position
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
      hParts.push('" target="_blank"><img height="48" width="48" src="');
      //hParts.push(result.img);
      hParts.push('" border="0"></a></div>\n');
    }
    hParts.push('<div class="tweetContentsContainer">');
    hParts.push('<div class="tweetUserNameContainer">');
    hParts.push('<a href="http://twitter.com/');
    hParts.push(result.name);
    hParts.push('" target="_blank">');
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
    setTimeout(function() {
        var img = new Image();
        img.onload = function() {
            listitem.getElementsByTagName("img")[0].setAttribute("src", result.img);
        }
        img.src = result.img;
    }, 100);
    listitem.innerHTML = stuff;
    tweetDumpList.appendChild(listitem);
    setTimeout(function() {
            insertTweets(results, i + 1, numTweets);
        }, 50);
    // yellow fade would be nice here....
}
