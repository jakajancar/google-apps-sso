Google Apps SSO Middleware
==========================

Only lets users signed into your Google Apps domain through.

Usage
-----

 1. Register an application in the [Google APIs Console](https://code.google.com/apis/console/).

 2. Include the SSO middleware (and `cookie-session`):

        var app = express();
        app.use(require('cookie-session')({secret: "..."}));
        app.use(require('google-apps-sso')('app id', 'app secret', 'yourcompany.com'));

    You can also use any other middleware that defines `req.session`, but keep in mind that it should be signed. It should also be encrypted if the site is not served over https, or replay attacks are possible.

 3. (optional) Use the user information

    After passing through the SSO middleware, the requests will have the `user` property defined:

        req.user = {email: "user@yourcompany.com", ...}

    The value is cached in the session cookie for 5 minutes between requests to Google.

 4. (optional) Logout

    Since the middleware does not explicitly prompt the user to log in but does it automatically, it makes little sense to log the user out by just destroying the local the session: the user will just be logged right back in.

    To clear the session as well as log the user out of Google Apps, call `res.logout()`.
