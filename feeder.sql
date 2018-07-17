create table Feed (
id integer primary key autoincrement,
name varchar(200) not null,
url varchar(200) not null,
created datetime not null,
refresh datetime null
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

create table User (
id integer primary key autoincrement,
login varchar(200) not null,
name varchar(200) not null,
email varchar(200) not null,
autologon varchar(200) null,
created datetime not null
);

create table Subscription (
id integer primary key autoincrement,
user_id int not null,
feed_id int not null,
label varchar(50) not null,
category varchar(200) not null,
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

