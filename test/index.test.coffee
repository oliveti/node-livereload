livereload = require '../lib/livereload'
should = require 'should'
request = require 'request'
http = require 'http'
url = require 'url'
fs = require 'fs'
path = require 'path'
WebSocket = require 'ws'
sinon = require 'sinon'

describe 'livereload http file serving', ->

  it 'should serve up livereload.js', (done) ->
    server = livereload.createServer({port: 35729})

    fileContents = fs.readFileSync('./ext/livereload.js').toString()

    request 'http://localhost:35729/livereload.js?snipver=1', (error, response, body) ->
      should.not.exist error
      response.statusCode.should.equal 200
      fileContents.should.equal body

      server.config.server.close()

      done()

  it 'should connect to the websocket server', (done) ->
    server = livereload.createServer({port: 35729})

    ws = new WebSocket('ws://localhost:35729/livereload')
    ws.on 'message', (data, flags) ->
      data.should.equal '!!ver:1.6'

      server.config.server.close()

      done()

  it 'should allow you to override the internal http server', (done) ->
    app = http.createServer (req, res) ->
      if url.parse(req.url).pathname is '/livereload.js'
        res.writeHead(200, {'Content-Type': 'text/javascript'})
        res.end '// nothing to see here'

    server = livereload.createServer({port: 35729, server: app})

    request 'http://localhost:35729/livereload.js?snipver=1', (error, response, body) ->
      should.not.exist error
      response.statusCode.should.equal 200
      body.should.equal '// nothing to see here'

      server.config.server.close()

      done()

  it 'should allow you to specify ssl certificates to run via https', (done)->
    server = livereload.createServer
      port: 35729
      https:
        cert: fs.readFileSync path.join __dirname, 'ssl/localhost.cert'
        key: fs.readFileSync path.join __dirname, 'ssl/localhost.key'

    fileContents = fs.readFileSync('./ext/livereload.js').toString()

    # allow us to use our self-signed cert for testing
    unsafeRequest = request.defaults
      strictSSL: false
      rejectUnauthorized: false

    unsafeRequest 'https://localhost:35729/livereload.js?snipver=1', (error, response, body) ->
      should.not.exist error
      response.statusCode.should.equal 200
      fileContents.should.equal body

      server.config.server.close()

      done()

describe 'livereload file watching', ->
  describe "config.delay", ->
    tmpFile = clock = server = refresh = undefined

    # modified this method from chokidar specs
    waitFor = (duration, spy, cb) ->
      spyIsReady = (spy) ->
        spy.callCount > 0
      finish = ->
        clearTimeout($to)
        clearInterval($int)
        cb()
        cb = Function.prototype
      $int = setInterval(
        ->
          if(spyIsReady(spy))
            finish()
        5
      )
      $to = setTimeout(finish, duration)

    beforeEach ->
      tmpFile = path.join(__dirname, "tmp.js")
      fs.writeFileSync(tmpFile, "use strict;", "utf-8")

    afterEach ->
      fs.unlinkSync(tmpFile)

    describe 'when `config.delay` is set', ->
      beforeEach (done) ->
        server = livereload.createServer({delay: 2000, port: 5050})
        refresh = sinon.spy(server, "refresh")
        server.watch(__dirname)
        # must wait for chokidar it seems
        setTimeout(done, 6000)

      it 'should send a refresh message after `config.delay` milliseconds', (done) ->
        refresh.callCount.should.be.exactly(0)
        fs.writeFileSync(tmpFile, "use strict; var a = 1;", "utf-8")

        waitFor(3000, refresh, ->
          refresh.callCount.should.be.exactly(1)
          done()
        )

    describe 'when `config.delay` is 0 or unset', ->
      beforeEach (done) ->
        server = livereload.createServer({delay: 0, port: 2020})
        refresh = sinon.spy(server, "refresh")
        server.watch(__dirname)
        # must wait for chokidar it seems
        setTimeout(done, 6000)

      it 'should send a refresh message near immediately if `config.delay` is falsey`', (done) ->
        refresh.reset()
        refresh.callCount.should.be.exactly(0)
        fs.writeFileSync(tmpFile, "use strict; var a = 1;", "utf-8")

        waitFor(100, refresh, ->
           refresh.callCount.should.be.exactly(1)
          done()
        )


  it 'should correctly watch common files', ->
    # TODO check it watches default exts

  it 'should correctly ignore common exclusions', ->
    # TODO check it ignores common exclusions

  it 'should not exclude a dir named git', ->
    # cf. issue #20
