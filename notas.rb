require "rubygems"
require "sinatra"
#require "sinatra/flash"
require "rack-flash"
require "sinatra/redirect_with_flash"
require "dm-core"
require "dm-migrations"
require "digest/sha1"
require "sinatra-authentication"
Bundler.require

use Rack::Session::Cookie, :secret => "noseQUE$%$#^$#esEsTo...P3r0Bueh!"

enable :sessions
use Rack::Flash

SITE_TITLE = "Notas - Venezuela"
SITE_DESCRIPTION = "Informacion que solo tiene significado para ti."

if ENV['VCAP_SERVICES'].nil?
  DataMapper::setup(:default, "sqlite3://#{Dir.pwd}/dev.db")
else
  require 'json'
  svcs = JSON.parse ENV['VCAP_SERVICES']
  postgre = svcs.detect { |k,v| k =~ /^postgresql/ }.last.first
  creds = postgre['credentials']
  user, pass, host, name = %w(user password host name).map { |key| creds[key] }
  DataMapper.setup(:default, "postgres://#{user}:#{pass}@#{host}/#{name}")
end

class Nota
  include DataMapper::Resource

  property :id, Serial
  property :content, Text, :required => true
  property :created_at, DateTime
  property :updated_at, DateTime

  #belongs_to :DmUser
end

class DmUser
  has n, :notas
end

DataMapper.finalize
DataMapper.auto_upgrade!

helpers do
  include Rack::Utils

  alias_method :h, :escape_html
end

# Index Action - Accion mostrar todas las notas existentes.
#                Realiza una consulta en la BD de todas las 
#                notas existentes y las muestra en la pagina index.
get "/" do
  #@notas = Nota.all :order => :id.desc
  #@notas = current_user.db_instance.notas
  @notas = Nota.all( :dm_user_id => current_user.id )
  @title = "Notas"
  
  erb :index
end

get "/favicon.ico" do
  redirect "/"
end

# Create Action - Accion guardar la nota.
#                 almacena en la BD la nota escrita
#                 en el formulario de la pagina index.
post "/" do
  login_required
  n = Nota.new
  n.content = params[:content]
  n.created_at = Time.now
  n.updated_at = Time.now
  n.dm_user_id = current_user.id
  if n.save
    redirect "/", :notice => "Nota guardada!"
  else
    redirect "/", :error => "Error al almacenar la Nota..."
  end
end

# Edit Action - Accion editar la nota seleccionada (por su id).
#               muestra el contenido de la nota en un formulario
#               para su edicion.
get "/:id" do
  login_required
  @nota = Nota.get params[:id] 
  @title = "Estas editando la Nota ##{params[:id]}"
  if @nota && @nota.dm_user_id == current_user.id
    if @nota
      erb :edit
    else
      redirect "/", :error => "No se ha encontrado la Nota ##{params[:id]}"
    end
  else  
    redirect "/", :error => "Esta nota no te pertenece o no existe"
  end
end

# Update Action - Accion actualizar la nota seleccionada (por su id).
#                 guarda en la BD la nota modificada en el formulario
#                 generado por la Accion Edit de arriba.
put "/:id" do
  login_required
  n = Nota.get params[:id]
  unless n
    redirect "/", :error => "No se ha encontrado esta Nota"
  end

  n.content = params[:content]
  n.updated_at = Time.now
  if n.save
    redirect "/", :notice => "Nota Actualizada!"
  else
    redirect "/", :error => "Error modificando la Nota"
  end
end

# Accion similar a la Edit Action, solo que esta solo muestra el contenido
# de la nota y pregunta por la confirmacion si se desea eliminar o cancelar.
get "/:id/delete" do
  login_required
  @nota = Nota.get params[:id]
  @title = "Confirma la eliminacion de la Nota ##{params[:id]}"
  if @nota && @nota.dm_user_id == current_user.id
    if @nota
      erb :delete
    else
      redirect "/", :error => "No se ha encontrado esta Nota..."
    end
  else
    redirect "/", :error => "Esta nota no te pertenece o no existe"
  end
end

# Delete Action - Accion eliminar  la nota seleccionada (por su id)
#                 elimina la nota mostrada de la BD.
delete "/:id" do
  login_required
  n = Nota.get params[:id]
  if n.destroy
    redirect "/", :notice => "Nota Eliminada!"
  else
    redirect "/", :error => "Error eliminando la Nota..."
  end
end
