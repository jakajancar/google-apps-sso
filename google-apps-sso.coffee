https       = require 'https'
querystring = require 'querystring'
request     = require 'request'

module.exports = (clientId, clientSecret, domain) ->
    (req, res, next) ->
        origin          = "http://#{req.headers.host}" # TODO: passable in or use X-Forwarded-For for scheme
        redirectPath    = '/oauth2callback'
        refreshInterval = 60000

        authUrl = (state) ->
            'https://accounts.google.com/o/oauth2/auth?' + querystring.stringify
                response_type:  'code'
                client_id:      clientId
                redirect_uri:   origin + redirectPath
                scope:          'https://www.googleapis.com/auth/userinfo.email https://www.googleapis.com/auth/userinfo.profile'
                state:          state
                hd:             domain # documented only for OAuth 1, but it seems to work for 2 also

        redirectToAuthUrl = (state, message) ->
            res.writeHead 302,
                'Content-Type': 'text/plain; charset=utf-8'
                Location:       authUrl(state)
            res.end message

        # Clears the session and logs the user out
        res.logout = (message='Logging out...') ->
            req.session = null
            res.writeHead 302,
                'Content-Type': 'text/plain; charset=utf-8'
                # `continue` accepts only Google URLs, but luckily oauth2/auth is Google :)
                Location:       'https://www.google.com/accounts/Logout?&continue=' + encodeURIComponent(authUrl(origin + '/'))
            res.end message

        # OAuth 2 callback
        if req.url.indexOf(redirectPath) == 0
            # Exchange code for token
            request.post(
                {
                    url: 'https://accounts.google.com/o/oauth2/token'
                    form:
                        code:           req.query.code
                        client_id:      clientId
                        client_secret:  clientSecret
                        redirect_uri:   origin + redirectPath # weird that we have to send this here, but we do
                        grant_type:     'authorization_code'
                }
                (error, tokenRes, body) ->
                    # Redirect to either state or login
                    if !error and tokenRes.statusCode == 200
                        body = JSON.parse(body)
                        req.session.ga = {token: body.access_token}
                        res.writeHead 302, {'Location': req.query.state}
                        res.end ''
                    else
                        # Invalid token
                        redirectToAuthUrl req.query.state, 'Could not exchange code for token.'
            )
            return

        if not req.session.ga
            # Not authenticated, redirect to login/allow access
            redirectToAuthUrl origin + req.url, 'Please log in.'
        else
            # Authenticated
            cachedUserInfoReady = ->
                #  { id: '1234567890',
                #    email: 'person@domain.com',
                #    verified_email: true,
                #    name: 'First Last',
                #    given_name: 'First',
                #    family_name: 'Last',
                #    link: 'https://plus.google.com/123456790',
                #    picture: 'https://lh3.googleusercontent.com/.../photo.jpg',
                #    gender: 'male',
                #    locale: 'en',
                #    hd: 'domain.com' }
                req.user = req.session.ga.cachedUserInfo
                if req.user.hd != domain
                    redirectToAuthUrl origin + req.url, "#{req.user.email} is not a member of #{domain}"
                    return

                next()

            # Refresh user info if needed
            if (new Date - (req.session.ga.lastRefresh or 0)) >= refreshInterval
                request(
                    {
                        url: 'https://www.googleapis.com/oauth2/v1/userinfo'
                        headers:
                            Authorization: 'Bearer ' + req.session.ga.token
                    }
                    (error, infoRes, body) ->
                        if !error and infoRes.statusCode == 200
                            req.session.ga.lastRefresh = +new Date
                            req.session.ga.cachedUserInfo = JSON.parse(body)
                            cachedUserInfoReady()
                        else
                            res.logout 'Could not get user info.'
                )
            else
                cachedUserInfoReady()
