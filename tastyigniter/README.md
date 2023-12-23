# tastyigniter
Setup TastyIgniter with Docker

Download this repository:
```
git clone https://github.com/ocrot/tastyigniter.git
cd tastyigniter
```

Create and edit .env file:
```
cp .env.example .env
nano .env
```

Run docker-compose:
```
docker-compose up -d
```

Open http://localhost:80/setup.php in your browser (replace localhost with your server's ip or domain name) and follow the instructions.
