OAuth2 = require("oauth").OAuth2
sys = require("util")

GOOGLE_CONNECT_EVENT = "googleConnect"

exports.init = initGoogleConnect = ->
  console.log "Initializing google connect..."
  try
    settings = require("#{app.root}/config/environment").GoogleAPI
  catch e
    console.error "Could not init Google Auth extension, env-specific settings not found in config/environment"
    console.error "Error:", e.message
  initApp settings if settings

initApp = (settings) ->
  _clientId = settings.clientId
  _clientSecret = settings.clientSecret
  _clientUri = settings.clientUri
  _authPath = settings.authPath
  _tokenPath = settings.tokenPath
  _clientConnectPath = settings.clientConnectPath
  _clientAuthPath = settings.clientAuthPath
  _authUri = settings.authUri
  _scope = settings.scope
  _scopeUrl = settings.scopeUrl

  _oauth2 = new OAuth2(_clientId, _clientSecret, _authUri, _authPath, _tokenPath)

  app.get _clientConnectPath, (req, res) ->
    #console.log req.headers
    req.session.beforeGoogleAuth = req.headers.referer
    delete req.session.google

    params =
      response_type: "code"
      redirect_uri: _clientUri + _clientAuthPath

    if _scope and Array.isArray(_scope)
      _scope = _scope.join(" ")  if Array.isArray(_scope)
    params.scope = _scope
    url = _oauth2.getAuthorizeUrl(params)
    res.redirect url

  app.get _clientAuthPath, (mainRequest, mainResponse) ->
    redirectBack = (req, res, flash) ->
      location = req.session and req.session.beforeGoogleAuth or "/"
      delete req.session.beforeGoogleAuth

      if flash
        if flash.error
          req.flash "error", flash.error
        else req.flash "info", flash.info  if flash.info
      res.redirect location

    googleCallback = (error, data, res) ->
      if error
        redirectBack mainRequest, mainResponse,
          error: "Error getting google screen name : " + sys.inspect(error)

        console.error "gotData:", error
      else
        data = JSON.parse(data)  if typeof data is "string"

        app.emit GOOGLE_CONNECT_EVENT, data, mainRequest, mainResponse

        if settings.autoRedirect
          redirectBack mainRequest, mainResponse

    if mainRequest.query and mainRequest.query.code
      gotToken = (error, accessToken, refreshToken) ->
        if error
          redirectBack mainRequest, mainResponse,
            error: "Error getting OAuth request token : " + sys.inspect(error)
        else
          mainRequest.session.google =
            oauthRequestToken: accessToken
            oauthRequestRefreshToken: refreshToken

          _oauth2.get _scopeUrl, accessToken, googleCallback
      _oauth2.getOAuthAccessToken mainRequest.query.code,
        redirect_uri: _clientUri + _clientAuthPath
        grant_type: "authorization_code"
      , gotToken
