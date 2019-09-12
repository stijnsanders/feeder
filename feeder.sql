create table "Feed" (
id serial primary key,
name varchar(200) not null,
url varchar(200) not null,
created float not null,
flags int null,
urlskip varchar(50) null,
loadlast float null,
result varchar(1000) null,
loadcount int null,
itemcount int null,
regime int null,
totalcount int null
);

create table "Post" (
id serial primary key,
feed_id integer not null,
guid varchar(800) not null,
title varchar(1000) not null,
content text not null,
url varchar(800) not null,
pubdate float not null,
created float not null,
constraint FK_Post_Feed foreign key (feed_id) references "Feed" (id)
);

create index IX_Post on "Post" (feed_id);
--create index IX_PostGuid on "Post" (guid,feed_id);--//moved to index db kept by eater

create table "User" (
id serial primary key,
login varchar(200) not null,
name varchar(200) not null,
email varchar(200) not null,
timezone int null,
batchsize int null,
created float not null
);

create table "UserLogon" (
id serial primary key,
user_id int not null,
key varchar(200) not null,
created float not null,
last float not null,
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
postsopened int null,
created float not null,
constraint FK_Subscription_User foreign key (user_id) references "User" (id),
constraint FK_Subscription_Feed foreign key (feed_id) references "Feed" (id)
);

create index IX_Subscription on "Subscription" (user_id,feed_id);
create index IX_Subscription_Cat on "Subscription" (user_id,category,feed_id);

create table "UserPost" (
id serial primary key,
user_id int not null,
post_id int not null,
constraint FK_UserPost_User foreign key (user_id) references "User" (id),
constraint FK_UserPost_Post foreign key (post_id) references "Post" (id)
);

create unique index IX_UserPost on "UserPost" (user_id,post_id);

insert into "Feed" (id,name,url,created) values (0,'[system messages]','',0.0);

/*
alter table "Feed" add column totalcount int null;
update "Feed" set totalcount=X.totalcount
from (select P.feed_id, count(*) as totalcount
from "Post" P group by P.feed_id) X where X.feed_id="Feed".id;
*/

create table "SubCount" (
id serial primary key,
month int not null,
subscription_id int not null,
postsopened int not null,
constraint FK_SubCount_Subscription foreign key (subscription_id) references "Subscription" (id)
);

create unique index IX_SubCount on "SubCount" (month,subscription_id);
