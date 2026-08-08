# AzerothPW — Perfect World 1.5.5

Native install on Ubuntu 22.04 x64. Client: RU Build 2567 el-156 t-128.

## Quick install

```bash
git clone https://github.com/Sakhwoow/AzerothPW.git
cd AzerothPW
PUBLIC_IP=YOUR_IP MYSQL_PASS=yourpassword bash install.sh
```

## Client config

Port: **29000**

`element\dbserver.conf`:
```
address = YOUR_IP
port = 29000
```

## Account creation

```sql
INSERT INTO users (name, passwd, email, creatime)
VALUES ('login', TO_BASE64(UNHEX(MD5(CONCAT('login','password')))), 'email@example.com', NOW());
```
