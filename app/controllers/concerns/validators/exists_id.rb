class ExistsId < Grape::Validations::Base
  def validate_param!(attr_name, params)
    klass = @option.to_s.classify.constantize

    unless klass.exists?(id: params[attr_name])
      fail Grape::Exceptions::Validation,
           params: [@scope.full_name(attr_name)],
           message: "#{@option} is not found. :id => #{params[attr_name]}"
    end
  end
end
