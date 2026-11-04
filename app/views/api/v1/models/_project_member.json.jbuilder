json.id resource.id
json.project_id resource.project_id
json.user_id resource.user_id
if resource.user.present?
  json.user do
    json.id resource.user.id
    json.name resource.user.name
    json.email resource.user.email
    json.thumbnail resource.user.avatar_url
  end
else
  json.user nil
end
json.created_at resource.created_at.to_i
