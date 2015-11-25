class ExistsId < Grape::Validations::Base
  def validate_param!(attr_name, params)
    klass = @option.to_s.classify.constantize

    rc = klass.find_by(id: params[attr_name])

    unless rc
      fail Grape::Exceptions::Validation,
           params: [@scope.full_name(attr_name)],
           message: "#{@option} is not found. :id => #{params[attr_name]}"
    end
  end
end
