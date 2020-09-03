for i in {1..10}; do
    k patch cm/mysql-migration \
      -n app-$i \
      --type merge \
      -p "{\"data\":{\"DB\": \"app_$i\"}}"
done
