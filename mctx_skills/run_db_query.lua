return {
    name = 'run_db_query',
    description = 'Sua descrição aqui',
    parameters = {
        { name = 'arg1', type = 'string', required = true, desc = 'Descrição do argumento' }
    },
    execute = function(args)
        return 'Resultado da skill'
    end
}
