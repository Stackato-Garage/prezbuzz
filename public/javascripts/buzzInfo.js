/*
 * Copyright (c) 2011 ActiveState Software Inc.
 * See the file LICENSE.txt for licensing information.
 */

// Class for the main buzzInfo.  This class handles most of the interaction
// between the server and the JS UI.  Get the global vars, # tweets,
// current candidate, and whether the prev and next links are working.

function BuzzInfo() {
}
BuzzInfo.prototype = {
    chart: null,
    checkOlderLinksID: 0,
    checkNewerLinksID: 0,
    refreshChartTimeoutID: 0,
    refreshInterval: 10 * 60 * 1000, // update every 10 minutes
    linkCheckDelay: 60 * 1000, // check once a minute
    mmToMonth: ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "July", "Aug", "Sep", "Oct", "Nov", "Dec"],
    safeDateRE: /^(\d\d\d\d)-(\d\d)-(\d\d)T(\d\d:\d\d:\d\d)([\-\+])(\d\d):(\d\d)/,
    widgets: {},
    
    pluralizeWord: function(word, count) {
          if (count == 1) return word;
          return word + "s";
    },
    
    __END__: null
};
BuzzInfo.prototype.onLoad = function() {
    this.widgets.prevLinksElement = document.getElementById('button_time_back');
    this.widgets.nextLinksElement = document.getElementById('button_time_forward');
    if (!this.widgets.nextLinksElement) {
        alert("internal error: onload: can't find button_time_forward");
    }
};

BuzzInfo.prototype.processNameInfo = function(candidates, candidates_to_drop, data) {
    var i, fullName, clickCol = 0, dataCol = 0, candidate;
    this.colors_for_candidates = [];
    this.clickColumnToDataColumn = [];
    data.addColumn('string', 'month');
    for (i = 0; (candidate = candidates[i]); i++) {
        if (!candidates_to_drop[candidate.id]) {
            fullName = candidate.firstName + " " + candidate.lastName;
            data.addColumn('number', fullName);
            this.candidateNames.push(fullName);
            this.colors_for_candidates.push("#" + candidate.color);
            this.clickColumnToDataColumn[clickCol] = dataCol;
            clickCol += 1;
        }
        dataCol += 1;
    }
};

BuzzInfo.prototype.getFilteredCandidates = function(candidates, candidates_to_drop) {
    var candidate, filteredCandidates = [], i;
    for (i = 0; (candidate = candidates[i]); i++) {
        if (!candidates_to_drop[candidate.id]) {
            filteredCandidates.push(candidate);
        }
    }
    return filteredCandidates;
};

BuzzInfo.prototype.mouseEventHandler = function(event) {
    var dataColumn, clickColumn, selection = this.chart.getSelection()[0];
    if (!selection) {
        //alert("clickHandler: no selection!... ");
        return;
    }
    row = selection.row;
    clickColumn = selection.column - 1; // col 0 for date
    var candidateName = this.candidateNames[clickColumn];
    $("body").attr("class", candidateName);
    this.showSelectedCandidate(clickColumn, row);
};


BuzzInfo.prototype.processIntervalInfo = function(intervalInfo, candidates, candidates_to_drop, results, data) {
    var candidate, dataRow, filteredCandidates, i, interval, j, num_tweets_by_candidate, startDate,
        thisCandidatePosnTweetCounts;
    
    dateLabels = results.dateLabels;
    var formatTimes = ["%b %d %Y, %i:%M %p", "%i:%M %p"];
    var formatIndex = 0;
    var formatLen = formatTimes.length;
    num_tweets_by_candidate = results.num_tweets_by_candidate;
    filteredCandidates = this.getFilteredCandidates(candidates, candidates_to_drop);
    this.isoStartDates = [];
    for (i = 0; (interval = intervalInfo[i]); i++) {
        num_tweets_by_candidate = interval.num_tweets_by_candidate;
        this.isoStartDates.push(interval.startDate);
        dataRow = [this.getSafeDate(interval.startDate).strftime(formatTimes[formatIndex])];
        thisCandidatePosnTweetCounts = [];
        this.intervalCandidatePosnTweetCounts.push(thisCandidatePosnTweetCounts);
        for (j = 0; (candidate = filteredCandidates[j]); j++) {
            dataRow.push(num_tweets_by_candidate[candidate.id]);
            thisCandidatePosnTweetCounts.push(num_tweets_by_candidate[candidate.id]);
        }
        data.addRow(dataRow);
        if (formatIndex < formatLen - 1) {
            formatIndex += 1;
        }
    }
};

/*
 * see tweets_controller#getChartInfo for a list of what's in results
 */

function dumpit(obj) {
    var retParts = [];
    for (var p in obj) {
        try {
            var o = obj[p];
            if (typeof(o) != "function") {
                retParts.push(p + ":" + obj[p])
            }
        } catch(ex) {}
    }
    return "{" + retParts.join("\n") + "}";
}
BuzzInfo.prototype.processChart = function(results) {
//    alert("processChart: this:" + dumpit(this))
    // Incoming data:
    clearTimeout(this.refreshChartTimeoutID);
    if (this.chart) {
       delete this.chart;
       // would be nice to remove the listener
       // google.visualization.events.addListener(this.chart, 'select', function(event) { thisBuzzInfo.mouseEventHandler(event); });
    }
    var intervalInfo = results.intervalInfo;
    var candidates = results.candidates;
    var candidates_to_drop = results.candidates_to_drop;
    var isoFinalEndDate = results.isoFinalEndDate;
    //var intervalInfo = results.intervalInfo;
    
    this.intervalCandidatePosnTweetCounts = [];
    this.candidateNames = [];
    this.clickColumnToDataColumn = [];
    this.gEndDate = isoFinalEndDate;
    this.gNumRows = intervalInfo.length;
    
    var thisBuzzInfo = this;
    
    // Create and populate the data table.
    var data = new google.visualization.DataTable(); // Not same as the "dataTable" template parameter
    this.processNameInfo(candidates, candidates_to_drop, data);
    this.processIntervalInfo(intervalInfo, candidates, candidates_to_drop, results, data);
    this.processLinkInfo(results);
    this.updateLinkInfo();
       
    // Create and draw the visualization.
    this.chart = new google.visualization.ColumnChart(document.getElementById('visualization'));
    this.chart.draw(data, {curveType: "function",
                    enableEvents: true,
                      title: "Tweets per hour",
                      colors: this.colors_for_candidates,
                    width: 1050, height: 400,
                    vAxis: {maxValue: results.maxSize} }
            );
    google.visualization.events.addListener(this.chart, 'select', function(event) { thisBuzzInfo.mouseEventHandler(event); });

    this.showSuggestedCandidate(results);
    initSidebar();
    var thisBuzzInfo = this;
    this.refreshChartTimeoutID = setTimeout(function() { thisBuzzInfo.refreshChart(); }, this.refreshInterval);
};

BuzzInfo.prototype.processLinkInfo = function(results) {
    var linkInfo = results.linkInfo;
    if (!linkInfo) return;
    this.linkInfo = {
      hasPrevLinks: linkInfo.hasPrevLinks,
      prevLinkStartDate: linkInfo.prevLinkStartDate,
      prevLinkEndDate: linkInfo.prevLinkEndDate,
      hasNextLinks: linkInfo.hasNextLinks,
      nextLinkStartDate: linkInfo.nextLinkStartDate,
      nextLinkEndDate: linkInfo.nextLinkEndDate
    };
};

BuzzInfo.prototype.updateLinkInfo = function() {
    var thisBuzzInfo = this;
    if (this.linkInfo.hasPrevLinks) {
        this.setPrevLink();
        $('#button_time_back').attr('disabled', '');
    } else {
        $('#button_time_back').attr('disabled', 'true');
        this.checkOlderLinksID = setInterval(function() { thisBuzzInfo.checkOlderLinks(); }, this.linkCheckDelay);
    }
    if (this.linkInfo.hasNextLinks) {
        this.setNextLink();
        $('#button_time_forward').attr('disabled', '');
    } else {
        $('#button_time_forward').attr('disabled', 'true');
        this.checkNewerLinksID = setInterval(function() { thisBuzzInfo.checkNewerLinks(); }, this.linkCheckDelay);
    }
};

BuzzInfo.prototype.showSelectedCandidate = function(clickNum, intervalNum) {
    // loadCandidateContent - uses click columns
    this.loadCandidateContent(clickNum, intervalNum);
    this.getTweets(clickNum, intervalNum);
}

BuzzInfo.prototype.showAnyCandidate = function() {
    // Load the most recent tweets that are available for a candidate,
    // starting with the first in the list.
    // We should really update this based on the last candidate looked at,
    // and see if we got to this page from an earlier page or a later one.
    var clickNum, intervalNum;
    for (clickNum = 0; clickNum < this.clickColumnToDataColumn.length; clickNum++) {
        for (intervalNum = 3; intervalNum >= 0; intervalNum--) {
            if (this.intervalCandidatePosnTweetCounts[intervalNum][clickNum] > 0) {
                this.showSelectedCandidate(clickNum, intervalNum);
                return;
            }
        }
    }
};
    
BuzzInfo.prototype.showSuggestedCandidate = function(results) {
    var clickNum, intervalNum, suggestedCandidate = results.suggestedCandidate;
    if (suggestedCandidate === null) {
        this.showAnyCandidate();
    } else {
        try {
            // The controller specifies which candidate to load.
            // Figure out the click num for this
            for (clickNum = 0; clickNum < this.clickColumnToDataColumn.length; clickNum++) {
                if (this.clickColumnToDataColumn[clickNum] + 1 == suggestedCandidate) {
                    for (intervalNum = 3; intervalNum >= 0; intervalNum--) {
                        if (this.intervalCandidatePosnTweetCounts[intervalNum][clickNum] > 0) {
                            this.showSelectedCandidate(clickNum, intervalNum);
                            return;
                        }
                    }
                }
            }
        } catch(ex) {
            alert("internal error: problem in showSuggestedCandidate: get first batch of tweets " + ex);
        }
    }
};

BuzzInfo.prototype.getTimeParts = function(dt) {
    var hour = dt.getHours();
    var ap;
    if (hour > 12) {
        hour = hour - 12;
        ap = "pm";
    } else if (hour == 12) {
        ap = "pm";
    } else {
        ap = "am";
        if (hour === 0) {
            hour = 12;
        }
    }
    return [hour, ap];
};

BuzzInfo.prototype.getSafeDate = function(timeStamp) {
    // Do it this way for Safari & IE.
    // Mozilla & Chrome js can parse ISO 8601 formats
    var m = this.safeDateRE.exec(timeStamp);
    if (!m) return new Date(timeStamp);
    var yr = m[1], mon=m[2], day=m[3], hrMinSec=m[4], 
        sign=m[5], offsetHour=m[6], offsetMin=m[7];
    var timeStr = (yr + "/" + mon + "/" + day
                   + " "
                   + hrMinSec
                   + " UTC"
                   + sign
                   + offsetHour
                   + offsetMin);
    return new Date(timeStr);
};

BuzzInfo.prototype.showLocalDate = function(startDate, endDate) {
    var sdt = this.getSafeDate(startDate);
    var s_mm = this.mmToMonth[sdt.getMonth()];
    var s_hour, s_ap;
    var parts = this.getTimeParts(sdt);
    s_hour = parts[0];
    s_ap = parts[1];

    var edt = this.getSafeDate(endDate);
    var e_mm = this.mmToMonth[edt.getMonth()];
    var e_hour, e_ap;
    parts = this.getTimeParts(edt);
    e_hour = parts[0];
    e_ap = parts[1];
    
    var timeString;
    if (sdt.getDate() == edt.getDate() || edt.getHours() == 0) {
        timeString = ("on " + sdt.strftime("%b %d, %Y @ %i:%M"));
        if (s_ap == e_ap) {
            timeString += (" - " + edt.strftime("%i:%M %p"));
        } else {
            timeString += (sdt.strftime(" %p") + " - " + edt.strftime("%i:%M %p"));
        }
    } else {
        // Spans different days
        timeString = ("on " + sdt.strftime("%b %d, %Y @ %i:%M%p")
                      + " - " + edt.strftime("%b %d, %i:%M%p"));
    }
    return timeString;
};


BuzzInfo.prototype.getTweets = function(clickColumn, row) {
    var thisBuzzInfo = this;
    var dataColumn = this.clickColumnToDataColumn[clickColumn];
    var candidateNum = dataColumn + 1;
    var localCallback = function(results) {
        getTweetCallback(results);
        setTimeout(function() {
          jQuery.getJSON(thisBuzzInfo.getWordCloudURL,
                    { candidateNum:candidateNum, startDateISO:thisBuzzInfo.isoStartDates[0],
                      endDateISO: thisBuzzInfo.gEndDate
                    },
                    getWordCloudCallback); // in candidateBuzz.js
        }, 100);
    };
    var obj = this.getStartAndEndDates(row);
    jQuery.getJSON(this.getTweetsURL,
              { candidateNum:dataColumn + 1, startDateISO: obj.startDate,
                endDateISO: obj.endDate
              },
              localCallback);
};

BuzzInfo.prototype.loadCandidateContent = function(clickColumn, row) {
    var candidateName = this.candidateNames[clickColumn];
    var lastName = candidateName.split(/[\s,]+/)[1];
    
    // set body class
    $("body").attr("class", candidateName);
    
    // update candidate bar
    var candidateImg = '<img src="/images/' + lastName + '.jpg" >';
    $('div#buzz_candidate_img').html(candidateImg);
    
    var obj = this.getStartAndEndDates(row);
    var numTweets = this.getTotalTweetCount(clickColumn, row);
    $('div#buzz_candidate span#tweet_count').html(numTweets + " " + this.pluralizeWord("tweet", numTweets) + " ");
    $('div#buzz_candidate div#buzz_candidate_details strong').html(candidateName);
    $('div#buzz_candidate div#buzz_candidate_details span#time').html(this.showLocalDate(obj.startDate, obj.endDate));
};

BuzzInfo.prototype.getEndDate = function(row) {
    if (row < this.gNumRows - 1) {
        return this.isoStartDates[row  + 1];
    } else {
        return this.gEndDate;
    }
};

BuzzInfo.prototype.getStartAndEndDates = function(row) {
    var obj = {};
    if (typeof(row) === "undefined") {
        obj.startDate = this.isoStartDates[0];
        obj.endDate = this.gEndDate;
    } else {
        obj.startDate = this.isoStartDates[row];
        obj.endDate = this.getEndDate(row);
    }
    return obj;
}

BuzzInfo.prototype.getTotalTweetCount = function(clickColumn, row) {
    if (typeof(row) === "undefined") {
      var count = 0;
      var len = this.intervalCandidatePosnTweetCounts.length;
      for (var i = 0; i < len ; i++) {
        count += this.intervalCandidatePosnTweetCounts[i][clickColumn];
      }
      return count;
    } else {
      return this.intervalCandidatePosnTweetCounts[row][clickColumn];
    }
};


BuzzInfo.prototype.updateOlderLinks = function(result) {
    if (result) {
        clearInterval(this.checkOlderLinksID);
        this.checkOlderLinksID = 0;
        this.setPrevLink(result);
    }
};
BuzzInfo.prototype.updateNewerLinks = function(result) {
    if (result) {
        clearInterval(this.checkNewerLinksID);
        this.checkNewerLinksID = 0;
        this.setNextLink(result);
    }
};
BuzzInfo.prototype.setPrevLink = function(result) {
    clearInterval(this.checkNewerLinksID);
    this.checkNewerLinksID = 0;
    this.widgets.prevLinksElement.setAttribute("hasLink", 1);
};
BuzzInfo.prototype.setNextLink = function(result) {
    clearInterval(this.checkNewerLinksID);
    this.checkNewerLinksID = 0;
    this.widgets.nextLinksElement.setAttribute("hasLink", 1);
    //this.widgets.nextLinksElement.innerHTML = payload;
};
BuzzInfo.prototype.checkOlderLinks = function() {
    var this_ = this;
    jQuery.getJSON(this.checkOlderLinksURL,
                   {startDateISO:this.linkInfo.prevLinkStartDate,
                    endDateISO: this.linkInfo.prevLinkNextDate},
                    function(result) { this_.updateOlderLinks(result); });
};
BuzzInfo.prototype.checkNewerLinks = function() {
    var this_ = this;
    jQuery.getJSON(this.checkNewerLinksURL,
                   {startDateISO:this.linkInfo.nextLinkStartDate,
                    endDateISO: this.linkInfo.nextLinkNextDate},
                    function(result) { this_.updateNewerLinks(result); });
};
BuzzInfo.prototype.getPrevChart = function() {
    var thisBuzzInfo = this;
    jQuery.getJSON(this.getChartURL,
                   {startDateISO:this.linkInfo.prevLinkStartDate,
                    endDateISO: this.linkInfo.prevLinkEndDate},
                    function(results) { thisBuzzInfo.processChart(results); });
};
BuzzInfo.prototype.getNextChart = function() {
    var thisBuzzInfo = this;
    jQuery.getJSON(this.getChartURL,
                   {startDateISO:this.linkInfo.nextLinkStartDate,
                    endDateISO: this.linkInfo.nextLinkEndDate},
                    function(results) { thisBuzzInfo.processChart(results); });
};

BuzzInfo.prototype.refreshChart = function() {
    var thisBuzzInfo = this;
    clearTimeout(this.refreshChartTimeoutID); this.refreshChartTimeoutID = 0;
    jQuery.getJSON(this.getChartURL,
                  {startDateISO: this.gStartDate,
                   endDateISO: this.gEndDate},
                    function(results) { thisBuzzInfo.processChart(results); });
};
