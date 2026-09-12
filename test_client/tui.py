# tui.py
"""
Интерактивный TUI к серверу quantumde1 (JSON-версия).

Запуск:
    python tui.py
    python tui.py --host 127.0.0.1 --port 8080

Управление:
    ↑/↓, j/k  — навигация
    Enter     — выбрать / подтвердить
    Esc       — назад
    q         — выход (на главном экране)
    Tab       — в формах перейти к следующему полю
    Ctrl+C    — выход
"""

import argparse
import curses
import sys

from client import Client, ApiError


# ======================================================================
# Утилиты отрисовки
# ======================================================================
def safe_addstr(win, y, x, text, attr=0):
    """addstr, который не падает на границе окна."""
    try:
        h, w = win.getmaxyx()
        if y < 0 or y >= h or x < 0 or x >= w:
            return
        max_len = w - x - 1
        if max_len <= 0:
            return
        win.addstr(y, x, text[:max_len], attr)
    except curses.error:
        pass


def draw_bar(win, y, text, attr=curses.A_REVERSE):
    h, w = win.getmaxyx()
    safe_addstr(win, y, 0, " " * (w - 1), attr)
    safe_addstr(win, y, 2, text, attr)


def draw_header(stdscr, state):
    h, w = stdscr.getmaxyx()
    draw_bar(stdscr, 0, " quantumde1 TUI  —  JSON mode", curses.A_REVERSE | curses.A_BOLD)
    if state["user"]:
        u = state["user"]
        user_str = f"user: {u.get('name', '?')} (#{u.get('id', '?')})"
    else:
        user_str = "not logged in"
    safe_addstr(stdscr, 1, 2, user_str)
    safe_addstr(stdscr, 1, w - 18, "format: json")


def draw_footer(stdscr, hints):
    h, w = stdscr.getmaxyx()
    line = " | ".join(hints)
    safe_addstr(stdscr, h - 1, 0, " " * (w - 1), curses.A_REVERSE)
    safe_addstr(stdscr, h - 1, 2, line, curses.A_REVERSE)


def show_message(stdscr, title, lines, wait=True):
    stdscr.clear()
    h, w = stdscr.getmaxyx()
    safe_addstr(stdscr, 2, 2, title, curses.A_BOLD)
    for i, line in enumerate(lines):
        safe_addstr(stdscr, 4 + i, 4, str(line))
    draw_footer(stdscr, ["Enter / Esc — назад"])
    stdscr.refresh()
    if wait:
        while True:
            ch = stdscr.getch()
            if ch in (10, 13, 27, curses.KEY_ENTER):
                break


def prompt(stdscr, label, hidden=False, default=""):
    """Ввод строки. Возвращает строку или None (Esc)."""
    h, w = stdscr.getmaxyx()
    stdscr.clear()
    safe_addstr(stdscr, 2, 4, label, curses.A_BOLD)
    safe_addstr(stdscr, 4, 4, "> ")
    if default:
        safe_addstr(stdscr, 4, 6, default)
    stdscr.refresh()

    curses.echo(False)
    curses.curs_set(1)
    buf = list(default)
    while True:
        stdscr.move(4, 6 + len(buf))
        stdscr.clrtoeol()
        shown = "*" * len(buf) if hidden else "".join(buf)
        safe_addstr(stdscr, 4, 6, shown)
        stdscr.refresh()
        ch = stdscr.getch()
        if ch in (10, 13, curses.KEY_ENTER):
            curses.curs_set(0)
            return "".join(buf)
        if ch == 27:
            curses.curs_set(0)
            return None
        if ch in (curses.KEY_BACKSPACE, 127, 8):
            if buf:
                buf.pop()
            continue
        if 32 <= ch < 127:
            buf.append(chr(ch))
    # unreachable


def prompt_int(stdscr, label, default=None):
    while True:
        default_str = str(default) if default is not None else ""
        s = prompt(stdscr, label, default=default_str)
        if s is None:
            return None
        s = s.strip()
        if s == "" and default is not None:
            return default
        try:
            return int(s)
        except ValueError:
            show_message(stdscr, "Ошибка", [f"Нужно число, получено: {s!r}"], wait=True)


def select_from_list(stdscr, title, items, footer_hints=None):
    """Меню с навигацией. Возвращает индекс или None."""
    if not items:
        show_message(stdscr, title, ["(пусто)"])
        return None
    sel = 0
    while True:
        stdscr.clear()
        h, w = stdscr.getmaxyx()
        safe_addstr(stdscr, 2, 2, title, curses.A_BOLD)
        for i, item in enumerate(items):
            attr = curses.A_REVERSE if i == sel else 0
            line = f"  {item}"
            safe_addstr(stdscr, 4 + i, 2, line.ljust(w - 4), attr)
        if footer_hints:
            draw_footer(stdscr, footer_hints)
        stdscr.refresh()

        ch = stdscr.getch()
        if ch in (curses.KEY_UP, ord("k")):
            sel = (sel - 1) % len(items)
        elif ch in (curses.KEY_DOWN, ord("j")):
            sel = (sel + 1) % len(items)
        elif ch in (10, 13, curses.KEY_ENTER):
            return sel
        elif ch == 27:
            return None


# ======================================================================
# Экраны
# ======================================================================
def screen_auth(stdscr, client, state):
    """Меню входа/регистрации."""
    options = [
        "Login",
        "Register",
        "Back",
    ]
    while True:
        idx = select_from_list(stdscr, "=== AUTH ===", options,
                               ["Enter — выбрать", "Esc — назад", "q — выход"])
        if idx is None or idx == 2:
            return
        if idx == 0:
            do_login(stdscr, client, state)
        elif idx == 1:
            do_register(stdscr, client, state)


def do_login(stdscr, client, state):
    nick = prompt(stdscr, "Nickname:")
    if nick is None or not nick.strip():
        return
    pwd = prompt(stdscr, "Password:", hidden=True)
    if pwd is None:
        return
    try:
        raw = client.login(nick.strip(), pwd)
    except ApiError as e:
        show_message(stdscr, "API error", [str(e)])
        return

    if raw.strip() == "success":
        # нужно узнать id — API не отдаёт его при логине
        uid = find_user_id(client, nick.strip())
        if uid is None:
            show_message(stdscr, "Login", ["Успех, но не удалось найти id."])
            return
        try:
            state["user"] = client.user_info(uid)
        except ApiError as e:
            show_message(stdscr, "API error", [str(e)])
            return
        show_message(stdscr, "Login", [f"Добро пожаловать, {nick}!"])
    else:
        show_message(stdscr, "Login failed", [raw.strip() or "(пусто)"])


def do_register(stdscr, client, state):
    nick = prompt(stdscr, "Nickname:")
    if nick is None or not nick.strip():
        return
    pwd = prompt(stdscr, "Password:", hidden=True)
    if pwd is None:
        return
    try:
        raw = client.register(nick.strip(), pwd)
    except ApiError as e:
        show_message(stdscr, "API error", [str(e)])
        return
    show_message(stdscr, "Register", [raw.strip() or "(пусто)"])


def find_user_id(client, nick, limit=256):
    """Линейный поиск id по имени — API не даёт поиска."""
    for uid in range(limit):
        try:
            u = client.user_info(uid)
        except ApiError:
            continue
        if not isinstance(u, dict):
            continue
        if "error" in u:
            continue
        if u.get("name") == nick:
            return uid
    return None


def screen_user_info(stdscr, client, state):
    if not state["user"]:
        show_message(stdscr, "User info", ["Сначала войдите."])
        return
    uid = state["user"]["id"]
    try:
        u = client.user_info(uid)
    except ApiError as e:
        show_message(stdscr, "API error", [str(e)])
        return

    if not isinstance(u, dict) or "error" in u:
        show_message(stdscr, "User info", [f"Ошибка: {u}"])
        return

    lines = [
        f"id:         {u.get('id')}",
        f"name:       {u.get('name')}",
        f"balance:    {u.get('balance')}",
        f"productsCount:  {u.get('betsCount')}",
        f"products:       {u.get('bets')}",
        f"productsNames:  {u.get('betsNames')}",
    ]
    show_message(stdscr, f"User #{uid}", lines)


def screen_update_balance(stdscr, client, state):
    if not state["user"]:
        show_message(stdscr, "Balance", ["Сначала войдите."])
        return
    uid = state["user"]["id"]
    amount = prompt_int(stdscr, f"New balance for #{uid}:",
                        default=state["user"].get("balance", 0))
    if amount is None:
        return
    try:
        raw = client.update_balance(uid, amount)
    except ApiError as e:
        show_message(stdscr, "API error", [str(e)])
        return
    show_message(stdscr, "Update balance", [raw or "(пусто)"])


def screen_bets_list(stdscr, client, state):
    """Список ставок: 0..N, пока не 404. Кэшируем, чтобы не долбить сервер."""
    if "bets_cache" not in state:
        state["bets_cache"] = {}
    items = []
    max_scan = 128
    for bid in range(max_scan):
        try:
            b = client.bet_info(bid)
        except ApiError:
            break
        if not isinstance(b, dict) or "error" in b:
            break
        state["bets_cache"][bid] = b
        name = b.get("name", "?")
        price = b.get("price", 0)
        p1 = b.get("participantOneName", "?")
        p2 = b.get("participantTwoName", "—")
        status = "closed" if b.get("status") else "open"
        items.append(f"#{bid:>3}  [{status}]  {name}  price={price}  {p1} vs {p2}")

    if not items:
        show_message(stdscr, "Products", ["Продуктов нет (или сервер недоступен)."])
        return

    while True:
        idx = select_from_list(stdscr, "=== PRODUCTS ===", items,
                               ["Enter — открыть", "Esc — назад"])
        if idx is None:
            return
        # найдём betId по idx — items идут по порядку 0..N
        bet_ids = sorted(state["bets_cache"].keys())
        if idx >= len(bet_ids):
            continue
        bet_id = bet_ids[idx]
        screen_bet_detail(stdscr, client, state, bet_id)
        # перечитываем список после действий
        return screen_bets_list(stdscr, client, state)


def screen_bet_detail(stdscr, client, state, bet_id):
    try:
        b = client.bet_info(bet_id)
    except ApiError as e:
        show_message(stdscr, "API error", [str(e)])
        return
    if not isinstance(b, dict) or "error" in b:
        show_message(stdscr, "Bet", [f"Ошибка: {b}"])
        return

    lines = [
        f"id:                    {b.get('id')}",
        f"name:                  {b.get('name')}",
        f"price:                 {b.get('price')}",
        f"Seller index:   {b.get('participantOneIndex')}",
        f"Buyer index:   {b.get('participantTwoIndex')}",
        f"Seller name:    {b.get('participantOneName')}",
        f"Buyer name:    {b.get('participantTwoName')}",
        f"unixTimestamp:         {b.get('unixTimestamp')}",
        f"status:                {b.get('status')}",
    ]
    show_message(stdscr, f"Product #{bet_id}", lines)

    # действия
    actions = [
        "Add to cart",
        "Remove from cart",
        "Stop auction",
        "do not use pls",
        "Send product",
        "Remove product",
        "Back",
    ]
    idx = select_from_list(stdscr, f"=== BET #{bet_id} — ACTION ===", actions,
                           ["Enter — выполнить", "Esc — назад"])
    if idx is None or idx == 6:
        return

    if not state["user"]:
        show_message(stdscr, "Error", ["Сначала войдите."])
        return
    uid = state["user"]["id"]

    try:
        if idx == 0:  # take
            price = prompt_int(stdscr, "Your price:", default=b.get("price", 0))
            if price is None:
                return
            raw = client.bet_take(uid, bet_id, price)
        elif idx == 1:  # untake
            raw = client.bet_untake(uid, bet_id)
        elif idx == 2:  # stop
            raw = client.bet_stop(bet_id)
        elif idx == 3:  # result win for #2
            raw = client.bet_result(bet_id, True)
        elif idx == 4:  # result win for #1
            raw = client.bet_result(bet_id, False)
        elif idx == 5:  # remove
            raw = client.bet_remove(uid, bet_id)
        else:
            return
    except ApiError as e:
        show_message(stdscr, "API error", [str(e)])
        return

    show_message(stdscr, "Result", [raw or "(пусто)"])


def screen_create_bet(stdscr, client, state):
    if not state["user"]:
        show_message(stdscr, "Add product", ["Сначала войдите."])
        return
    uid = state["user"]["id"]
    name = prompt(stdscr, "Bet name:")
    if name is None or not name.strip():
        return
    price = prompt_int(stdscr, "Price:", default=0)
    if price is None:
        return
    p1 = prompt_int(stdscr, "Participant one id:", default=uid)
    if p1 is None:
        return
    try:
        raw = client.bet_register(name.strip(), price, p1)
    except ApiError as e:
        show_message(stdscr, "API error", [str(e)])
        return
    show_message(stdscr, "Create bet", [raw or "(пусто)"])


def screen_flush(stdscr, client, state):
    try:
        raw = client.flush()
    except ApiError as e:
        show_message(stdscr, "API error", [str(e)])
        return
    show_message(stdscr, "Flush", [raw or "(пусто)"])


# ======================================================================
# Главное меню
# ======================================================================
def main_menu(stdscr, client, state):
    while True:
        options = []
        if state["user"]:
            options += [
                f"User info (#{state['user']['id']})",
                "Update balance",
            ]
        else:
            options += ["Login / Register"]

        options += [
            "Products list",
            "Add product",
            "Flush to disk",
            "Logout" if state["user"] else "Quit",
        ]

        idx = select_from_list(stdscr, "=== MAIN MENU ===", options,
                               ["↑/↓ — навигация", "Enter — выбрать", "q — выход"])
        if idx is None:
            return

        # сопоставляем индекс с действием
        actions = []
        if state["user"]:
            actions.append("user_info")
            actions.append("update_balance")
        else:
            actions.append("auth")
        actions.append("bets")
        actions.append("create_bet")
        actions.append("flush")
        actions.append("logout" if state["user"] else "quit")

        action = actions[idx]

        if action == "user_info":
            screen_user_info(stdscr, client, state)
        elif action == "update_balance":
            screen_update_balance(stdscr, client, state)
        elif action == "auth":
            screen_auth(stdscr, client, state)
        elif action == "bets":
            screen_bets_list(stdscr, client, state)
        elif action == "create_bet":
            screen_create_bet(stdscr, client, state)
        elif action == "flush":
            screen_flush(stdscr, client, state)
        elif action == "logout":
            state["user"] = None
            state["bets_cache"] = {}
        elif action == "quit":
            return


# ======================================================================
# Точка входа
# ======================================================================
def run(stdscr, client):
    curses.curs_set(0)
    stdscr.keypad(True)

    state = {"user": None}

    while True:
        stdscr.clear()
        draw_header(stdscr, state)
        stdscr.refresh()
        try:
            main_menu(stdscr, client, state)
            # если main_menu вернулся — значит пользователь выбрал Quit
            return
        except KeyboardInterrupt:
            return


def parse_args():
    p = argparse.ArgumentParser(description="TUI-фронтенд к quantumde1 (JSON)")
    p.add_argument("--host", default="127.0.0.1")
    p.add_argument("--port", type=int, default=8080)
    p.add_argument("--timeout", type=float, default=10.0)
    return p.parse_args()


def main():
    args = parse_args()
    client = Client(host=args.host, port=args.port, timeout=args.timeout)
    try:
        curses.wrapper(run, client)
    except KeyboardInterrupt:
        pass
    except Exception as e:
        print(f"Fatal: {e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())