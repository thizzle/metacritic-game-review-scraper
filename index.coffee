###
# Metacritic Game Review Scraper
# @author Tharsan Bhuvanendran <me@tharsan.com>
# @version 0.5.0
#
# Scrape the metacritic.com web site for game review data, and output it in CSV format to `stdout`.
###

csv     = require 'csv-string'
util    = require 'util'
http    = require 'http'
async   = require 'async'
jsdom   = require 'jsdom'

# css selectors for targeting each required piece of information on a page
selectors =
  platform:  '#main .content_head .product_title .platform'
  title:     '#main .content_head .product_title a'
  userreview:
    reviews: 'ol.user_reviews > li'
    source:  '.review_stats .review_critic .name'
    score:   '.review_stats .review_grade.userscore'
    date:    '.review_stats .review_critic .date'
  criticreview:
    reviews:  'ol.critic_reviews > li'
    source:  '.review_stats .review_critic .source'
    score:   '.review_stats .review_grade.critscore'
    date:    '.review_stats .review_critic .date'

# scrape
# page (number)     the page number to scrape
# platform (string) the platform to scrape
# letter (string)   the leading title character to scrape
scrape = (page, platform, letter, done) ->
  jsdom.env
    html: "http://www.metacritic.com/browse/games/title/#{platform}/#{letter}?page=#{page}"
    done: (errors, window) ->
      links = window.document.querySelectorAll '.product_condensed > ol.list_products > li a'
      if links.length
        async.series
          links: (callback) ->
            for link in links
              scrapegame link.getAttribute('href'), callback
          (err, results) ->
            scrape ++page, platform, letter, done
      else
        done()

letters = [ '' ]

for charCode in [65..90]
  letter = String.fromCharCode(charCode).toLowerCase()
  letters.push letter

async.eachLimit letters, 4, (letter, done) ->
  scrape 0, 'xbox360', letter, done

scrapegame = (url, done) ->
  async.parallel
    critic: (callback) ->
      jsdom.env
        html: "http://www.metacritic.com#{url}/critic-reviews"
        done: (errors, window) ->
          if errors
            console.error errors
          else
            scrapereview window.document, 'criticreview', callback

    user: (callback) ->
      jsdom.env
        html: "http://www.metacritic.com#{url}/user-reviews"
        done: (errors, window) ->
          if errors
            console.error errors
          else
            scrapereview window.document, 'userreview', callback
    (err, results) ->
      done(err, results)

scrapereview = (document, reviewtype, callback) ->
  # catch error pages
  # metacritic doesn't follow Internet rules with correct HTTP response codes
  #  instead, errors are 200 OK responses, so we search for error module content
  #  in the response body
  if document.querySelector '.errorcode_module'
    return

  type     = if reviewtype is 'criticreview' then 'Expert' else 'User'
  platform = document.querySelector(selectors.platform).textContent.trim()
  title    = document.querySelector(selectors.title).textContent.trim()

  reviews = document.querySelectorAll selectors[reviewtype].reviews
  for review in reviews
    source = review.querySelector(selectors[reviewtype].source).textContent.trim()
    score  = review.querySelector(selectors[reviewtype].score).textContent.trim()
    date   = review.querySelector(selectors[reviewtype].date)?.textContent.trim()

    console.log csv.stringify([ title, platform, type, date, score, source ]).trim()

  callback(null, reviews.length)
  return
