import os
from datetime import date

import mysql.connector
from flask import Flask, jsonify, render_template, request
from mysql.connector import IntegrityError, Error

app = Flask(__name__)


def get_db():
    return mysql.connector.connect(
        host=os.getenv("DB_HOST", "localhost"),
        port=int(os.getenv("DB_PORT", "3306")),
        user=os.getenv("DB_USER", "root"),
        password=os.getenv("DB_PASSWORD", ""),
        database=os.getenv("DB_NAME", "club_management"),
    )


def rows(query, params=()):
    db = get_db()
    try:
        cur = db.cursor(dictionary=True)
        cur.execute(query, params)
        return cur.fetchall()
    finally:
        db.close()


@app.get("/")
def home():
    return render_template("index.html")


@app.get("/api/summary")
def summary():
    data = rows("""SELECT (SELECT COUNT(*) FROM members WHERE status='active') active_members,
                        (SELECT COUNT(*) FROM events WHERE event_date >= NOW()) upcoming_events,
                        (SELECT COUNT(*) FROM bookings) total_bookings""")
    return jsonify(data[0])


@app.get("/api/members")
def list_members():
    return jsonify(rows("SELECT member_id,first_name,last_name,email,phone,joined_on,status FROM members ORDER BY last_name,first_name"))


@app.post("/api/members")
def add_member():
    data = request.get_json(silent=True) or {}
    required = ("first_name", "last_name", "email")
    if any(not str(data.get(k, "")).strip() for k in required):
        return jsonify(error="First name, last name, and email are required."), 400
    db = get_db()
    try:
        cur = db.cursor()
        cur.execute("INSERT INTO members (first_name,last_name,email,phone) VALUES (%s,%s,%s,%s)",
                    tuple(str(data.get(k, "")).strip() or None for k in (*required, "phone")))
        db.commit()
        return jsonify(member_id=cur.lastrowid), 201
    except IntegrityError:
        db.rollback()
        return jsonify(error="That email address is already registered."), 409
    except Error:
        db.rollback()
        return jsonify(error="Could not save member. Check the database connection and input."), 500
    finally:
        db.close()


@app.get("/api/events")
def list_events():
    return jsonify(rows("""SELECT e.event_id,e.title,e.description,e.event_date,e.location,e.capacity,
                         COUNT(b.booking_id) booked,e.capacity-COUNT(b.booking_id) seats_left
                         FROM events e LEFT JOIN bookings b USING(event_id)
                         GROUP BY e.event_id ORDER BY e.event_date"""))


@app.post("/api/bookings")
def book_event():
    data = request.get_json(silent=True) or {}
    try:
        member_id, event_id = int(data["member_id"]), int(data["event_id"])
    except (KeyError, TypeError, ValueError):
        return jsonify(error="Choose a member and an event."), 400
    db = get_db()
    try:
        db.start_transaction()
        cur = db.cursor(dictionary=True)
        cur.execute("SELECT capacity FROM events WHERE event_id=%s FOR UPDATE", (event_id,))
        event = cur.fetchone()
        if not event:
            db.rollback()
            return jsonify(error="Event not found."), 404
        cur.execute("SELECT status FROM members WHERE member_id=%s", (member_id,))
        member = cur.fetchone()
        if not member or member["status"] != "active":
            db.rollback()
            return jsonify(error="Only active members can book events."), 400
        cur.execute("SELECT COUNT(*) AS n FROM bookings WHERE event_id=%s", (event_id,))
        if cur.fetchone()["n"] >= event["capacity"]:
            db.rollback()
            return jsonify(error="This event is full."), 409
        cur.execute("INSERT INTO bookings (member_id,event_id) VALUES (%s,%s)", (member_id, event_id))
        db.commit()
        return jsonify(message="Booking confirmed."), 201
    except IntegrityError:
        db.rollback()
        return jsonify(error="This member already has a booking for that event."), 409
    except Error:
        db.rollback()
        return jsonify(error="Could not create booking. Check the database connection and input."), 500
    finally:
        db.close()


if __name__ == "__main__":
    app.run(debug=os.getenv("FLASK_DEBUG", "0") == "1")
