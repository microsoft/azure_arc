# To determine list of actions user / group can perform.
# Examples shown below uses sample user accounts (hr-user, hr-admin) & group (hr-administrators).
# Modify the user/group as appropriate based on your environment.
kubectl auth can-i --list --as hr-user
kubectl auth can-i --list --as hr-admin
kubectl auth can-i --list --as hr-user --namespace azure-arc-data
kubectl auth can-i --list --as hr-admin --namespace azure-arc-data


# To find if user / group can perform particular action on a resource
kubectl auth can-i get datacontrollers --as hr-admin --namespace azure-arc-data
kubectl auth can-i get datacontrollers --as hr-user --namespace azure-arc-data
kubectl auth can-i get sqlmi --as hr-user --namespace azure-arc-data
kubectl auth can-i get sqlmi --as hr-admin --namespace azure-arc-data
kubectl auth can-i get postgresql-11s --as hr-user --namespace azure-arc-data
kubectl auth can-i get postgresql-11s --as hr-admin --namespace azure-arc-data
kubectl auth can-i get postgresql-12s --as hr-admin --namespace azure-arc-data

kubectl auth can-i create datacontrollers --as hr-user --namespace azure-arc-data
kubectl auth can-i delete postgresql-12s --as hr-admin --namespace azure-arc-data

kubectl auth can-i delete postgresql-12s --as-group hr-administrators --namespace azure-arc-data
kubectl auth can-i create sqlmi --as-group hr-administrators --namespace azure-arc-data
kubectl auth can-i create sqlmi --as-group hr-users --namespace azure-arc-data

kubectl auth can-i edit postgresql-12s --as hr-admin --namespace azure-arc-data
kubectl auth can-i get postgresql-12s --as hr-admin --namespace azure-arc-data
kubectl auth can-i create postgresql-12s --as hr-admin --namespace azure-arc-data
kubectl auth can-i delete postgresql-12s --as hr-admin --namespace azure-arc-data
kubectl auth can-i edit postgresql-12s --as hr-admin --namespace azure-arc-data
kubectl auth can-i edit sqlmi --as hr-admin --namespace azure-arc-data
kubectl auth can-i create sqlmi --as hr-admin --namespace azure-arc-data
kubectl auth can-i create postgresql-11s --as hr-admin --namespace azure-arc-data
kubectl auth can-i update postgresql-11s --as hr-admin --namespace azure-arc-data

# To find if user / group can perform particular action on a instance
kubectl auth can-i get sqlmi/* --as hr-user
kubectl auth can-i create sqlmi/* --as hr-admin
kubectl auth can-i get postgresql-11s/* --as hr-user
kubectl auth can-i get postgresql-12s/* --as hr-user
kubectl auth can-i delete sqlmi/* --as hr-admin
kubectl auth can-i delete datacontrollers/* --as hr-admin
kubectl auth can-i delete datacontrollers/* --as hr-user
