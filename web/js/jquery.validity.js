/**
 * validity - jQuery validation plugin (https://github.com/gustavoconci/validity.js)
 * Copyright (c) 2017-2018, Gustavo Henrique Conci. (MIT Licensed)
 */

(function($) {
    $.fn.validity = function(settings) {
        var defaultSettings = {
                ignore: ':hidden'
            },
            settings = Object.assign({}, defaultSettings, settings),
            selector = ':input:not(' + settings.ignore + ')';

        var $forms = $(this),
            inputValidity = function($form, $inputs) {

                return function(e) {

                    var $input = $(this);

                    if (e.type === 'keyup' && (
                        !$input.val() ||
                        ($input.is(':radio') || $input.is(':checkbox') && !$input.is(':checked'))
                    )) return;

                    if (!$input.attr('name')) return;

                    if ($input.is(':radio')) {
                        $input = $inputs.filter('[name="' + $input.attr('name') + '"]');
                        if (!$input.prop('required')) {
                            return;
                        }
                    }

                    if (!$input.attr('required')) return;

                    var input = $input[0],
                        validity = input.validity;

                    if (input.checkValidity()) {

                        if ($input.is(':file, :radio, :checkbox')) {
                            $input.parent().addClass('valid').removeClass('error mismatch');
                        } else {
                            $input.addClass('valid').removeClass('error mismatch');
                        }

                        $input.next('label.error-message').remove();

                    } else {

                        if ($input.is(':file, :radio, :checkbox')) {
                            $input.parent().addClass('error').removeClass('valid');
                        } else {
                            $input.addClass('error').removeClass('valid');
                        }

                        $form.data('valid', false);

                        if (!$input.is(':file, :radio, :checkbox')) {
                            if (validity.valueMissing) {
                                $input.next('label.error-message').remove();
                                if ($input.attr('data-missing')) {
                                    input.setCustomValidity($input.attr('data-missing'));
                                }
                                $input.after(
                                    '<label ' +
                                        ($input.attr('id') ? 'for="' + $input.attr('id') + '" ' : '') +
                                        'class="error-message">' +
                                            input.validationMessage +
                                    '</label>'
                                );
                            } else {
                                input.setCustomValidity('');
                            }

                            if (e.type == 'focusout') {
                                if (validity.patternMismatch || validity.typeMismatch) {
                                    $input.addClass('mismatch');
                                    $input.next('label.error-message').remove();
                                    if ($input.attr('data-mismatch')) {
                                        input.setCustomValidity($input.attr('data-mismatch'));
                                    }
                                    $input.after(
                                        '<label ' +
                                            ($input.attr('id') ? 'for="' + $input.attr('id') + '" ' : '') +
                                            'class="error-message">' +
                                                input.validationMessage +
                                        '</label>'
                                    );
                                } else {
                                    input.setCustomValidity('');
                                }
                            }
                        }

                    }

                };

            };

        $forms.each(function() {
            var $form = $(this),
                $inputs = $form.find(selector);
            $form.attr('novalidate', true)
                .off('keyup.validity change.validity focusout.validity')
                .on('keyup.validity change.validity focusout.validity', selector, inputValidity($form, $inputs));
        });

        $.fn.valid = function() {
            var $group = $(this),
                $inputs = $group.find(selector);
                $group.data('valid', true);
                $inputs.each(inputValidity($group, $inputs));
            return $group.data('valid');
        };

        $.fn.reset = function() {
            var $form = $(this);
            $form.find(':input').removeClass('valid error mismatch')
                .filter(':file').parent().removeClass('valid error mismatch');
            $form[0].reset();
            return $form;
        };

        return $forms;
    };
})(jQuery);
