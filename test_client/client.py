# client.py
"""HTTP-клиент к серверу quantumde1. Всегда запрашивает JSON."""

import json
import urllib.request
import urllib.error
from urllib.parse import urlencode


class ApiError(Exception):
    pass


class Client:
    def __init__(self, host="127.0.0.1", port=8080, timeout=10.0):
        self.base = f"http://{host}:{port}"
        self.timeout = timeout

    # ---------- низкий уровень ----------
    def _request(self, method, path, body=None, query=None):
        url = self.base + path
        q = dict(query or {})
        q["format"] = "json"  # всегда JSON
        url += "?" + urlencode(q)

        data = None
        headers = {}
        if body is not None:
            data = json.dumps(body).encode("utf-8")
            headers["Content-Type"] = "application/json"

        req = urllib.request.Request(url, data=data, headers=headers, method=method)
        try:
            with urllib.request.urlopen(req, timeout=self.timeout) as resp:
                raw = resp.read().decode("utf-8", errors="replace")
        except urllib.error.HTTPError as e:
            raw = e.read().decode("utf-8", errors="replace")
            # сервер отдаёт 404 с JSON {"error":"no_user"} — вернём как dict
            try:
                return json.loads(raw)
            except json.JSONDecodeError:
                raise ApiError(f"HTTP {e.code}: {raw.strip() or e.reason}")
        except urllib.error.URLError as e:
            raise ApiError(f"Connection error: {e.reason}")

        text = raw.strip()
        if not text:
            return {}
        try:
            return json.loads(text)
        except json.JSONDecodeError:
            return {"_raw": text}

    def _post(self, path, body):
        return self._request("POST", path, body=body)

    def _get(self, path, query=None):
        return self._request("GET", path, query=query)

    # ---------- API ----------

    # POST-эндпоинты возвращают простой текст ("success"), не JSON.
    # Мы оборачиваем их в строку.

    def register(self, nickname, password):
        return self._get_raw_text("POST", "/userRegister",
                                  {"nickname": nickname, "passwordHash": password})

    def login(self, nickname, password):
        return self._get_raw_text("POST", "/userLogin",
                                  {"nickname": nickname, "passwordHash": password})

    def _get_raw_text(self, method, path, body):
        """Для POST-эндпоинтов, возвращающих plain text."""
        url = self.base + path + "?format=json"
        data = json.dumps(body).encode("utf-8")
        req = urllib.request.Request(
            url, data=data, method=method,
            headers={"Content-Type": "application/json"},
        )
        try:
            with urllib.request.urlopen(req, timeout=self.timeout) as resp:
                return resp.read().decode("utf-8", errors="replace").strip()
        except urllib.error.HTTPError as e:
            return e.read().decode("utf-8", errors="replace").strip()
        except urllib.error.URLError as e:
            raise ApiError(f"Connection error: {e.reason}")

    # GET-эндпоинты возвращают JSON

    def user_info(self, user_id):
        return self._get("/userInfo", {"id": user_id})

    def bet_info(self, bet_id):
        return self._get("/betInfo", {"id": bet_id})

    def flush(self):
        return self._get_raw_text("GET", "/flush", None)

    # POST-эндпоинты (plain text)

    def update_balance(self, user_id, balance):
        return self._post_text("/userUpdateBalance",
                               {"userId": user_id, "balance": balance})

    def bet_register(self, betname, price, participant_one):
        return self._post_text("/betRegister", {
            "betname": betname,
            "price": price,
            "participantOne": participant_one,
        })

    def bet_take(self, user_id, bet_id, bet_price):
        return self._post_text("/betTakePart", {
            "userId": user_id,
            "betId": bet_id,
            "betPrice": bet_price,
        })

    def bet_untake(self, user_id, bet_id):
        return self._post_text("/betUntakePart", {
            "userId": user_id, "betId": bet_id,
        })

    def bet_remove(self, user_id, bet_id):
        return self._post_text("/betRemove", {
            "userId": user_id, "betId": bet_id,
        })

    def bet_stop(self, bet_id):
        return self._post_text("/betStopAuction", {"betId": bet_id})

    def bet_result(self, bet_id, win):
        return self._post_text("/betSetResult", {
            "betId": bet_id, "betStatus": bool(win),
        })

    def _post_text(self, path, body):
        return self._get_raw_text("POST", path, body)