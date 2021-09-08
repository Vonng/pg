# 用户与角色

Users and Roles in PostgreSQL are very similar. When I set up the FreshPorts database back in mid-2000, I was using PostgreSQL 7.0.3 (that’s my best guess based on my [blog entry](http://www.freebsddiary.org/postgresql.php)). I suspect roles were not available then and were introduced with PostgreSQL 8. I am positive someone will correct me if that’s wrong.

I now [have a need](https://twitter.com/DLangille/status/1026296397358870530) to convert a user into a role, then add users to that role. Let’s see what happens.

I’m doing this on my development server, so there’s no concurrent access issue. I’ll just turn stuff off (disable the webserver, the scripts, etc).

## Creating the new users

```
begin;
ALTER ROLE www NOLOGIN;
CREATE USER www_dev  WITH LOGIN PASSWORD '[redacted]' IN ROLE www;
CREATE USER www_beta WITH LOGIN PASSWORD '[redacted]' IN ROLE www;
```

That went well, so I issued a COMMIT.

The two new users will have the same permission as the original user.

## Changing the login

The login credentials will need to be changed. This is my update:

```
#       $db = pg_connect("host=pg02.example.org dbname=freshports user=www password=oldpassword sslmode=require");
        $db = pg_connect("host=pg02.example.org dbname=freshports user=www_beta password=newpassword sslmode=require");
```

## Access rights

I also updated pg_hba.conf for this server.

```
#hostssl freshports      www          10.0.0.1/32             md5
hostssl  freshports      www_beta     10.0.0.1/32             md5
```

After changing pg_hba.conf, you have to tell PostgreSQL about it. This is the FreeBSD command for that:

```
sudo service postgresql reload
```

## It just worked

I was impressed with how straight forward this was.  <https://beta.freshports.org/> came right up.

I have three other users to convert to roles but if it’s as easy as the above, I should be finished in time for dinner.