Cadabra::Application.routes.draw do
  match ':controller(/:action(.:format))'
  match ':controller(/:action(/:id(.:format)))'
end
