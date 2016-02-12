/**
 * fetch.js
 * @author Tharsan Bhuvanendran
 *
 * A simple wrapper around the `node-fetch` module that gracefully handles
 * `429 Too Many Requests` responses by retrying a certain number of times.
 */

const DEFAULT_RETRY_INTERVAL = 10,
      RETRY_ATTEMPTS = 5;

const nfetch = require('node-fetch');

var fetch = function(url, opts, attempts) {
  if (undefined === attempts) {
    attempts = RETRY_ATTEMPTS;
  }

  return new Promise(function (resolve, reject) {
    nfetch(url, opts).then(function (res) {
      if (200 === res.status) {
        resolve(res.text());
      } else if (429 === res.status) {
        var retryAfter = parseInt(res.headers.get('retry-after'), 10)+1 || DEFAULT_RETRY_INTERVAL;
        if (attempts > 0) {
          setTimeout(function() {
            resolve(fetch(url, opts, attempts-1));
          }, (retryAfter*1000));
        } else {
          console.error("Exceeded request retry attempts for URL " + url);
          reject(new Error("Exceeded request retry attempts for URL " + url));
        }
      } else {
        console.error("Received status code " + res.status + " from server for URL " + url)
        reject(new Error("Received status code " + res.status + " from server for URL " + url));
      }
    }).catch(reject);
  });
}

module.exports = fetch;
