class ImportDriversWithOriginalIds < ActiveRecord::Migration[8.0]
  def up
    # Temporär die ID Constraints entfernen
    execute "ALTER TABLE drivers ALTER COLUMN id DROP DEFAULT;"

    # Lösche alle bestehenden Drivers (VORSICHT!)
    execute "TRUNCATE drivers RESTART IDENTITY CASCADE;"

    # Importiere mit originalen IDs
    execute <<-SQL
      INSERT INTO drivers (id, first_name, last_name, pin, vehicle_id, trailer_id, tablet_id, active, driver_type, created_at, updated_at) VALUES
      (1, 'Sergej', 'Berger', '1000', 0, 0, 0, false, 0, NOW(), NOW()),
      (2, 'Erwin', 'Meier', '1001', 2, 2, 3, true, 0, NOW(), NOW()),
      (3, 'Stefan', 'Rößle', '1002', 3, 4, 4, false, 0, NOW(), NOW()),
      (4, 'Helmut', 'Renner', '1003', 8, 0, 5, true, 0, NOW(), NOW()),
      (5, 'Ivan', 'Turaev', '1004', 0, 0, 8, true, 0, NOW(), NOW()),
      (6, 'Heinz', 'Hohlheimer', '1031', 0, 0, 7, false, 0, NOW(), NOW()),
      (8, 'Udo', 'Gsänger', '1007', 0, 0, 9, true, 0, NOW(), NOW()),
      (9, 'Bernd', 'Mack', '1008', 0, 0, 10, true, 0, NOW(), NOW()),
      (10, 'Manfred', 'Müller', '1009', 0, 0, 11, true, 0, NOW(), NOW()),
      (11, 'Rainer', 'Übele', '1010', 0, 0, 12, true, 0, NOW(), NOW()),
      (12, 'Bernhard', 'Brieger', '1011', 0, 0, 11, true, 0, NOW(), NOW()),
      (13, 'Michael', 'Meyer', '1012', 0, 0, 0, true, 0, NOW(), NOW()),
      (14, 'Martin', 'Rosenbauer', '1013', 0, 0, 0, false, 0, NOW(), NOW()),
      (15, 'Heiko', 'Hänel', '1014', 6, 0, 0, true, 2, NOW(), NOW()),
      (16, 'Hermann', 'Hüttinger', '1015', 17, 0, 0, true, 2, NOW(), NOW()),
      (17, 'Norbert', 'Glassner', '1016', 1, 0, 0, false, 2, NOW(), NOW()),
      (18, 'Wolfgang', 'Burkhard', '1017', 0, 0, 0, false, 0, NOW(), NOW()),
      (19, 'Heinrich', 'Herzner', '1018', 0, 0, 0, false, 0, NOW(), NOW()),
      (21, 'Udo', 'Dörfler', '1019', 0, 0, 0, false, 0, NOW(), NOW()),
      (22, 'Andreas', 'Schmidt', '1020', 0, 0, 0, true, 0, NOW(), NOW()),
      (23, 'Andreas', 'Siebentritt', '1021', 0, 0, 0, false, 0, NOW(), NOW()),
      (24, 'Werkstatt', 'Werkstatt', '1234', 0, 0, 0, true, 0, NOW(), NOW()),
      (25, 'Helmut', 'Kastner', '1023', 0, 0, 0, true, 0, NOW(), NOW()),
      (26, 'Stefan', 'Lobb', '1024', 0, 0, 13, false, 0, NOW(), NOW()),
      (27, 'Samuel', 'Wiedmann', '1025', 0, 0, 0, true, 0, NOW(), NOW()),
      (28, 'Jens', 'Lauber', '1026', 0, 0, 11, true, 1, NOW(), NOW()),
      (29, 'Hasan', 'Hadzic', '1028', 18, 0, 0, false, 2, NOW(), NOW()),
      (30, 'Maik', 'Kurtz', '1027', 0, 0, 0, false, 0, NOW(), NOW()),
      (31, 'Michael', 'Stengel', '1029', 0, 0, 0, true, 1, NOW(), NOW()),
      (32, 'Daniel', 'Bickel', '1030', 0, 0, 0, false, 0, NOW(), NOW()),
      (33, 'Stefan', 'Högner', '1005', 0, 0, 0, false, 0, NOW(), NOW()),
      (34, 'Werner', 'Dürnberger', '1032', 0, 0, 0, true, 0, NOW(), NOW()),
      (35, 'Carsten', 'Bürlein', '1033', 0, 0, 0, false, 0, NOW(), NOW()),
      (36, 'Wolfgang', 'Rössler', '1034', 0, 0, 0, true, 0, NOW(), NOW()),
      (37, 'Georgi', 'Hadzhistoyanov', '1031', 0, 0, 0, false, 0, NOW(), NOW()),
      (38, 'Ranko', 'Poplasen', '1035', 0, 0, 0, false, 0, NOW(), NOW()),
      (39, 'Andy', 'Pelcaru', '1036', 0, 0, 0, true, 0, NOW(), NOW()),
      (40, 'Wolfgang', 'Streich', '1037', 0, 0, 0, false, 0, NOW(), NOW()),
      (41, 'Werner', 'Schülein', '1038', 0, 0, 0, true, 0, NOW(), NOW()),
      (42, 'Dirk', 'Burghard', '1040', 0, 0, 0, false, 0, NOW(), NOW()),
      (43, 'Gerhard', 'Lindstädt', '1039', 0, 0, 0, true, 2, NOW(), NOW()),
      (44, 'Christian', 'Hauf', '1041', 0, 0, 0, true, 0, NOW(), NOW()),
      (46, 'Karl-Heinz', 'Fratz', '1042', 0, 0, 0, true, 0, NOW(), NOW()),
      (47, 'Georg', 'Gabelberger', '1043', 0, 0, 0, true, 0, NOW(), NOW()),
      (48, 'Hüseyin', 'Ünlü', '1044', 0, 0, 0, false, 0, NOW(), NOW()),
      (49, 'Willi', 'Heumann', '1045', 0, 0, 0, true, 0, NOW(), NOW()),
      (50, 'Sergej', 'Schmidt', '1048', 0, 0, 0, true, 0, NOW(), NOW()),
      (51, 'Sascha', 'Laux', '1049', 0, 0, 0, true, 0, NOW(), NOW()),
      (52, 'Werner', 'Meister', '1050', 0, 0, 0, true, 0, NOW(), NOW()),
      (53, 'Christian', 'Meister', '1051', 0, 0, 0, true, 0, NOW(), NOW()),
      (54, 'Frank', 'Metz', '1052', 0, 0, 0, false, 0, NOW(), NOW()),
      (55, 'Eduard', 'Baier', '1053', 0, 0, 0, true, 0, NOW(), NOW()),
      (56, 'Spedition', 'Sammüller', '', 0, 0, 0, true, 0, NOW(), NOW()),
      (57, 'Spedition', 'Schmalhofer', '', 0, 0, 0, true, 0, NOW(), NOW()),
      (58, 'Spedition', 'Reidl', '', 0, 0, 0, true, 0, NOW(), NOW()),
      (59, 'Mihai', 'Pilsu', '1054', 0, 0, 0, true, 0, NOW(), NOW()),
      (60, 'Ivan', 'Tichanow', '1055', 0, 0, 0, true, 0, NOW(), NOW()),
      (61, 'Dimitri', 'Pflaum', '1056', 0, 0, 0, true, 0, NOW(), NOW()),
      (62, 'Christian', 'Hiltner', '1057', 0, 0, 0, true, 0, NOW(), NOW()),
      (63, 'Markus', 'Altmann', '2612', 0, 0, 0, true, 0, NOW(), NOW()),
      (64, 'Florian', 'Laux', '1058', 0, 0, 0, true, 0, NOW(), NOW()),
      (65, 'Denis', 'Kunkel', '1059', 0, 0, 0, true, 0, NOW(), NOW()),
      (66, 'Reinhold', 'Jäger', '1060', 0, 0, 0, true, 0, NOW(), NOW()),
      (68, 'Maik', 'Schröter', '1061', 0, 0, 0, true, 0, NOW(), NOW()),
      (69, 'Vedat', 'Erdogan', '1062', 0, 0, 0, true, 0, NOW(), NOW()),
      (70, 'Jaroslaw', 'Przepiorka', '1063', 0, 0, 0, true, 0, NOW(), NOW()),
      (71, 'Christian', 'Riel', '1064', 0, 0, 0, true, 0, NOW(), NOW()),
      (72, 'Thomas', 'Von der Linden', '1065', 0, 0, 0, true, 0, NOW(), NOW()),
      (73, 'Robert', 'Kecseti', '1066', 0, 0, 0, true, 0, NOW(), NOW()),
      (74, 'Leonid', 'Schreider', '1068', 0, 0, 0, true, 0, NOW(), NOW()),
      (75, 'Marwan', 'Azeez', '1067', 0, 0, 0, true, 0, NOW(), NOW());
    SQL

    # Setze die Sequence auf den höchsten Wert
    execute "SELECT setval('drivers_id_seq', (SELECT MAX(id) FROM drivers));"

    # Setze Default wieder
    execute "ALTER TABLE drivers ALTER COLUMN id SET DEFAULT nextval('drivers_id_seq');"
  end

  def down
    execute "TRUNCATE drivers RESTART IDENTITY CASCADE;"
  end
end
