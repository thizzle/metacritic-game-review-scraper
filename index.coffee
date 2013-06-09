async   = require 'async'
fs      = require 'fs'
csv     = require 'csv-string'
Browser = require 'zombie'

browser = new Browser
  runScripts: false
  # debug: true
  site: 'http://www.metacritic.com'

next = (page, letter) ->
  browser.visit "/browse/games/title/xbox360/#{letter}?page=#{page}", (e) ->
    if e
      console.err e
    else
      links = browser.queryAll '.product_condensed > ol.list_products > li a'
      if links.length
        async.eachLimit links, 5, (item, cb) ->
          scrapegame item.getAttribute('href'), cb
        next ++page

    return

next 0, ''

for charCode in [65..90]
  letter = String.fromCharCode(charCode).toLowerCase()
  # next 0, letter

scrapegame = (url, cb) ->
  gamebrowser = new Browser
    runScripts: false
    # debug: true
    site: 'http://www.metacritic.com'

  gamebrowser.visit url + '/critic-reviews', (e) ->
    console.err e if e

    platform = "Xbox 360" #gamebrowser.query('#main .content_head .product_title .platform').textContent.trim()
    type     = "Expert"
    title    = gamebrowser.query('#main .content_head .product_title a')?.textContent.trim()

    reviews = gamebrowser.queryAll 'ol.critic_reviews > li'
    for review in reviews
      source = review.querySelector('.review_stats .review_critic .source')?.textContent.trim()
      score  = review.querySelector('.review_stats .review_grade.critscore')?.textContent.trim()
      date   = review.querySelector('.review_stats .review_critic .date')

      if date
        date = date.textContent.trim()
      else
        date = "Unknown"

      console.log csv.stringify([ title, platform, type, date, score, source ]).trim()

    gamebrowser.visit url + '/user-reviews', (e) ->
      console.err e if e

      platform = "Xbox 360" #gamebrowser.query('#main .content_head .product_title .platform').textContent.trim()
      type     = "User"
      title    = gamebrowser.query('#main .content_head .product_title a')?.textContent.trim()

      reviews = gamebrowser.queryAll 'ol.user_reviews > li'
      for review in reviews
        source = review.querySelector('.review_stats .review_critic .name')?.textContent.trim()
        score  = review.querySelector('.review_stats .review_grade.userscore')?.textContent.trim()
        date   = review.querySelector('.review_stats .review_critic .date')

        if date
          date = date.textContent.trim()
        else
          date = "Unknown"

        console.log csv.stringify([ title, platform, type, date, score, source ]).trim()

      cb()
      gamebrowser = null
      return

    return

  return
