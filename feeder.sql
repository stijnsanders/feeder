create table "Feed" (
id serial primary key,
name varchar(200) not null,
url varchar(200) not null,
created timestamp not null,
flags int null,
loadlast timestamp null,
result varchar(1000) null,
loadcount int null,
itemcount int null,
regime int null
);

create table "Post" (
id serial primary key,
feed_id integer not null,
guid varchar(500) not null,
title varchar(1000) not null,
content text not null,
url varchar(500) not null,
pubdate timestamp not null,
created timestamp not null,
constraint FK_Post_Feed foreign key (feed_id) references "Feed" (id)
);

create index IX_Post on "Post" (feed_id,pubdate);

create table "User" (
id serial primary key,
login varchar(200) not null,
name varchar(200) not null,
email varchar(200) not null,
timezone int null,
created timestamp not null
);

create table "UserLogon" (
id serial primary key,
user_id int not null,
key varchar(200) not null,
created timestamp not null,
last timestamp not null,
address varchar(50) not null,
useragent varchar(200) not null,
constraint FK_UserLogon_User foreign key (user_id) references "User" (id)
);

create table "Subscription" (
id serial primary key,
user_id int not null,
feed_id int not null,
label varchar(50) not null,
category varchar(200) not null,
color varchar(20) not null,
readwidth int not null,
created timestamp not null,
constraint FK_Subscription_User foreign key (user_id) references "User" (id),
constraint FK_Subscription_Feed foreign key (feed_id) references "Feed" (id)
);

create table "UserPost" (
id serial primary key,
user_id int not null,
post_id int not null,
constraint FK_UserPost_User foreign key (user_id) references "User" (id),
constraint FK_UserPost_Post foreign key (post_id) references "Post" (id)
);

create unique index IX_UserPost on "UserPost" (user_id,post_id);

insert into "Feed" (id,name,url,created) values (0,'[system messages]','',now());

grant select,insert,update,delete on all tables in schema public to feeder;
grant select,update on all sequences in schema public to feeder;