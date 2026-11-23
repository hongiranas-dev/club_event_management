-- Club management system: MySQL 8+
CREATE DATABASE IF NOT EXISTS club_management
  CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE club_management;

CREATE TABLE IF NOT EXISTS members (
  member_id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  first_name VARCHAR(60) NOT NULL,
  last_name VARCHAR(60) NOT NULL,
  email VARCHAR(254) NOT NULL,
  phone VARCHAR(30),
  joined_on DATE NOT NULL DEFAULT (CURRENT_DATE),
  status ENUM('active','inactive') NOT NULL DEFAULT 'active',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (member_id),
  CONSTRAINT uq_members_email UNIQUE (email),
  CONSTRAINT chk_members_email CHECK (email LIKE '%_@_%._%')
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS events (
  event_id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  title VARCHAR(120) NOT NULL,
  description TEXT,
  event_date DATETIME NOT NULL,
  location VARCHAR(160) NOT NULL,
  capacity SMALLINT UNSIGNED NOT NULL DEFAULT 30,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (event_id),
  CONSTRAINT chk_events_capacity CHECK (capacity > 0),
  INDEX idx_events_date (event_date)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS bookings (
  booking_id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  member_id INT UNSIGNED NOT NULL,
  event_id INT UNSIGNED NOT NULL,
  booked_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (booking_id),
  CONSTRAINT uq_booking_member_event UNIQUE (member_id, event_id),
  CONSTRAINT fk_bookings_member FOREIGN KEY (member_id) REFERENCES members(member_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_bookings_event FOREIGN KEY (event_id) REFERENCES events(event_id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  INDEX idx_bookings_event (event_id)
) ENGINE=InnoDB;

-- Safe to re-run: sample rows use explicit IDs and are inserted only when absent.
INSERT INTO members (member_id, first_name, last_name, email, phone, joined_on, status) VALUES
 (1,'Asha','Rao','asha.rao@example.com','+91-90000-00001','2026-01-12','active'),
 (2,'Kabir','Shah','kabir.shah@example.com','+91-90000-00002','2026-02-03','active'),
 (3,'Mira','Sen','mira.sen@example.com','+91-90000-00003','2026-03-20','inactive')
ON DUPLICATE KEY UPDATE email=VALUES(email);

INSERT INTO events (event_id, title, description, event_date, location, capacity) VALUES
 (1,'Monthly Meetup','Introductions, updates, and refreshments.','2026-12-05 17:00:00','Club Hall',40),
 (2,'Community Cleanup','A morning volunteering event.','2026-12-12 08:30:00','Riverside Park',25),
 (3,'Board Games Night','Bring a favorite game to share.','2026-12-18 18:00:00','Lounge Room',20)
ON DUPLICATE KEY UPDATE title=VALUES(title);

INSERT IGNORE INTO bookings (member_id, event_id) VALUES (1,1),(2,1),(1,3);

-- Example queries
-- List active members:
-- SELECT member_id, first_name, last_name, email FROM members WHERE status='active';
-- Events with confirmed booking count and remaining seats:
-- SELECT e.event_id,e.title,e.event_date,e.capacity,COUNT(b.booking_id) AS booked,
--        e.capacity-COUNT(b.booking_id) AS seats_left
-- FROM events e LEFT JOIN bookings b ON b.event_id=e.event_id
-- GROUP BY e.event_id ORDER BY e.event_date;
-- Book a member into an event (the app also checks capacity transactionally):
-- INSERT INTO bookings (member_id,event_id) VALUES (1,2);
-- Member booking history:
-- SELECT e.title,e.event_date,b.booked_at FROM bookings b JOIN events e USING(event_id)
-- WHERE b.member_id=1 ORDER BY e.event_date;
