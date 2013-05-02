INSERT INTO Users(userName, emailAddress, password) VALUES ('root', 'root@invalid.org', '8843d7f92416211de9ebb963ff4ce28125932878');
INSERT INTO UserRoles(userName, role) values('root', 'admin');
INSERT INTO UserRoles(userName, role) values('root', 'foo');
INSERT INTO Projects(name, displayname, owner) values('tests', '', 'root');
