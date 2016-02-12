/**
 * index.js
 * @author Tharsan Bhuvanendran <me@tharsan.com>
 *
 * Metacritic Game Scores Crawler
 * Scrape the metacritic.com web site for game review scores, both
 */

const CONCURRENT_REQUEST_LIMIT = 1,
      METACRITIC_BASE_URL = 'http://www.metacritic.com',
      GAME_LIST_URL_FORMAT = METACRITIC_BASE_URL + "/browse/games/release-date/available/%s/name?page=%d",
      REQUEST_OPTS = {
        headers: {
          'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_11_3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/48.0.2564.103 Safari/537.36',
        }
      };

const http = require('http'),
      url  = require('url'),

      $         = require('cheerio'),
      async     = require('async'),
      csvWriter = require('csv-write-stream'),
      fetch     = require('./fetch'),
      sprintf   = require('sprintf-js').sprintf;

// setup writer stream for writing CSV output to STDOUT
var writer = csvWriter({headers: ['title', 'platform', 'date', 'score', 'source']});
writer.pipe(process.stdout);

/**
 * scrapePlatform scrapes the platform list page for games.
 *
 * @platform string The name of the platform to scrape.
 * @page     int    The page number of the platform list to scrape.
 *
 * @return Promise
 */
function scrapePlatform(platform, page) {
  if (undefined == page) {
    page = 0;
  }

  return fetch(sprintf(GAME_LIST_URL_FORMAT, platform, page), REQUEST_OPTS).then(function(body) {
    var products = $('.product a', body);
    if (products.length) {
      // construct an array of URLs to each game on the list page
      var gameUrls = products.map(function (idx, anchor) {
        return anchor.attribs.href;
      });

      // scrape each game URL asynchronously
      async.eachLimit(gameUrls, CONCURRENT_REQUEST_LIMIT, scrapeGame, function(err) {
        if (err) {
          console.error(err);
        }

        // after all games have been processed, move onto the next page in the game list
        scrapePlatform(platform, page+1);
      });
    }
  }).catch(function (err) {
    console.error(err);
  });
}

/**
 * scrapeGame scrapes the game review page for user and critic reviews (on two separate pages).
 *
 * @param gameUrl  string   The base URL for the game.
 * @param callback function The callback to execute on completion.
 *
 * @return void
 */
function scrapeGame(gameUrl, callback) {
  var promises = [];

  // fetch and scrape critic reviews
  promises[0] = fetch(METACRITIC_BASE_URL + gameUrl + '/user-reviews?sort-by=date&num_items=100', REQUEST_OPTS).then(function (body) {
    var $body = $(body),
        record = {
          title: $('.product_title a', $body).text().trim(),
          platform: $('.platform', $body).text().trim(),
          source: 'user',
        };

    $('.user_reviews .review_content .review_section:first-child', $body).each(function (idx, review) {
      record['score'] = $('.metascore_w', review).text().trim();
      record['date'] = $('.review_critic .date', review).text().trim();
      writer.write(record);
    });
  });

  // fetch and scrape user reviews
  promises[1] = fetch(METACRITIC_BASE_URL + gameUrl + '/critic-reviews', REQUEST_OPTS).then(function (body) {
    var $body = $(body),
        record = {
          title: $('.product_title a', $body).text().trim(),
          platform: $('.platform', $body).text().trim(),
        };

    $('.critic_reviews .review_content .review_section:first-child', $body).each(function (idx, review) {
      record['score'] = $('.metascore_w', review).text().trim();
      record['date'] = $('.review_critic .date', review).text().trim();
      record['source'] = $('.review_critic .source', review).text().trim();
      writer.write(record);
    });
  });

  // wait for all scores to arrive before completion
  Promise.all(promises).then(function() {
    callback();
  }).catch(function(err) {
    callback(err);
  });
}

if (process.argv.length < 3) {
  console.error("Expected platform identifier as the only argument to this program.");
  console.error("Usage: npm run crawl -- psp");
  process.exit(1);
}

scrapePlatform(process.argv[2]);
