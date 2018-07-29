create table Feed (
id integer primary key autoincrement,
name varchar(200) not null collate nocase,
url varchar(200) not null,
created datetime not null,
flags int null,
loadlast datetime null,
result varchar(1000) null,
loadcount int null,
itemcount int null,
regime int null
);

create table Post (
id integer primary key autoincrement,
feed_id integer not null,
guid varchar(200) not null,
title varchar(200) not null,
content varchar(2000) not null,
url varchar(200) not null,
pubdate datetime not null,
created datetime not null,
constraint FK_Post_Feed foreign key (feed_id) references Feed (id)
);

create index IX_Post on Post (feed_id,pubdate);

create table User (
id integer primary key autoincrement,
login varchar(200) not null,
name varchar(200) not null,
email varchar(200) not null,
timezone int null,
created datetime not null
);

create table UserLogon (
id integer primary key autoincrement,
user_id int not null,
key varchar(200) not null,
created datetime not null,
last datetime not null,
address varchar(50) not null,
useragent varchar(200) not null,
constraint FK_UserLogon_User foreign key (user_id) references User (id)
);

create table Subscription (
id integer primary key autoincrement,
user_id int not null,
feed_id int not null,
label varchar(50) not null collate nocase,
category varchar(200) not null collate nocase,
color int not null,
readwidth int not null,
created datetime not null,
constraint FK_Subscription_User foreign key (user_id) references User (id),
constraint FK_Subscription_Feed foreign key (feed_id) references Feed (id)
);

create table UserPost (
id integer primary key autoincrement,
user_id int not null,
post_id int not null,
constraint FK_UserPost_User foreign key (user_id) references User (id),
constraint FK_UserPost_Post foreign key (post_id) references Post (id)
);

