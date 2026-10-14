"""
Flight Search API - Authentication script of the proxy
Signs in as the administrator registered by entrypoint.sh, adds its access token to every request (except those to the
authentication endpoints), and signs in again before the token expires (30 minutes). A 401 does not make it sign in
again: the API also answers 401 when it fails (its errors are forwarded to /error, which Spring Security protects), and
the tools cannot invalidate the token of the proxy (they never see it)
"""
import time
import requests
from mitmproxy import ctx

LOGIN_URL = "http://localhost:8080/api/v1/authentication/user/login"
CREDENTIALS = {"email": "admin@restgym.example", "password": "Password123!"}     # registered by entrypoint.sh
RENEW_BEFORE_SECONDS = 60       # sign in again this long before the token expires
RETRY_AFTER_SECONDS = 5         # after a failed sign-in, wait this long before trying again


class Authenticate:
    def __init__(self):
        self.token = None
        self.expires_at = 0         # epoch seconds (accessTokenExpiresAt of the API)
        self.failed_at = 0

    def sign_in(self):
        """Sign in and keep the access token and its expiration"""
        if time.time() - self.failed_at < RETRY_AFTER_SECONDS:
            return
        try:
            response = requests.post(LOGIN_URL, json=CREDENTIALS, timeout=30)
            body = response.json().get("response") or {}
            self.token = body["accessToken"]
            self.expires_at = body.get("accessTokenExpiresAt") or time.time() + 30 * 60
            ctx.log.info(f"[AUTH] Signed in as {CREDENTIALS['email']}: the token expires at {time.ctime(self.expires_at)}")
        except Exception as e:
            self.token = None
            self.failed_at = time.time()
            ctx.log.warn(f"[AUTH] Sign-in failed: {e}")

    def request(self, flow):
        # The authentication endpoints are left as the tools send them
        if "/api/v1/authentication/" in flow.request.path:
            return

        if self.token is None or time.time() >= self.expires_at - RENEW_BEFORE_SECONDS:
            self.sign_in()

        if self.token:
            flow.request.headers["Authorization"] = "Bearer " + self.token


addons = [Authenticate()]
