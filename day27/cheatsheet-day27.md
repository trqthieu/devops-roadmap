# docker logs
docker logs container # all logs
docker logs -f container # follow
docker logs --tail 50 container # last 50
docker logs -t container # timestamp
docker logs --since 30m container # last 30 mins
docker logs container 2>&1 | grep -i err

# docker inspect
docker inspect c --format "{{.State.Status}}"
docker inspect c --format "{{.State.ExitCode}}"
docker inspect c --format "{{.State.OOMKilled}}"
docker inspect c --format "{{json .State}}" | python3 -m json.tool
docker inspect c --format "{{json .Config.Env}}" | python3 -m json.tool

# docker exec
docker exec -it container sh
docker exec -u root container bash
docker exec container env | sort
docker exec container ps aux


