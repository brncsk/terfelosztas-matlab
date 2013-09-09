function [solutions, runtime, exitflag, output] = ...
    solveCommutingProblem(data, names, population, popNames, ranks, md, popSize, gens, tolFun, prioritize)

% 1. Adatok transzformációja és rendezése

    % Nevek és népességi értékek kiválogatása az országos vektorból
    [~,loc] = ismember(names, popNames);
    population = population(loc);
    ranks = ranks(loc);
    
    % Az elérhetőségi mátrix oszlopainak rendezése a megyei rangsor szerint
    sortedData = sortrows(horzcat(num2cell(ranks),num2cell(population),names), 1);
    sortedPop = cell2mat(sortedData(:,2));
    sortedNames = sortedData(:,3);

    data = sortrows(horzcat(ranks,data), 1);
    data(:,1) = [];
    data = data';

    % A súlyozási mátrix létrehozása
    costs = data * diag(sortedPop);

    
% 2. A problémaméret minimalizálása

    binData = (data <= md);
    
    while sum(sum(binData, 2) ~= 0) == size(binData,1)
        binData(:,size(binData,2)) = [];
    end
    
    problemSize = size(binData, 2) + 1;
        
% 3. Opciók beállítása
    
    % Kezdeti populációt létrehozó függvény (jelenleg nincs használatban)
    cf = @(gl, ff, op) commuteCreationFcn(gl, ff, op, expectedDistrictCount);
    
    % Célfüggvény
    ff = @(pop) commuteFitnessFcn(pop, data, costs, population, ranks, md, prioritize);

    % Opciók
    options = gaoptimset(                       ...
        'Display',              'iter',         ...
        'PopulationType',       'bitstring',    ...
        'Generations',          gens,           ...
        'TolFun',               tolFun,         ...
                                                ...
        'PopulationSize',       popSize,        ...
        'StallGenLimit',        10,             ...
                                                ...
        'UseParallel',          'always',       ...
        'PlotFcns',             {@gaplotpareto} ...
     );

% 4. Futtatás

    tic;
    
    [x, fval, exitflag, output, ~, ~] = ...
        gamultiobj(ff, problemSize, [], [], [], [], [], [], options);
    
    runtime  = toc;

% 5. Eredmények megjelenítése
    function [solutions] = dumpSolutions(primary)
        feasIdcs = find(fval(:,primary) == min(fval(:,primary)));
        feasX = x(feasIdcs,:)';
        solutions = cell(length(feasIdcs),5);
        for i=1:length(feasIdcs)
            [solutions{i, :}] = normalizeResults(feasX(:,i), data, sortedPop, costs, names, sortedNames, md);
        end
    end

    solutions = dumpSolutions(1);
end

function [score] = commuteFitnessFcn (vars, data, costs, popData, ranks, md, prioritize)

% Az egyed értéke
    score = zeros(3, 1);
    
% Az egyed méretének bővítése a teljes probléma méretére
    vars(size(data, 1)) = 0;

    data(:, ~logical(vars == 1)) = Inf;
    
% Az egyed ingázási súlyának kiszámítása
    for i = 1:length(data)
        minValue = min(data(i, :));

        if (minValue > md) || (minValue == Inf)
            score = inf(length(score), 1);
            return;
        end

        score(2) = score(2) + costs(i, find(data(i, :) == minValue, 1));
    end

% Az egyed értékének meghatározása attól függően, hogy előnyben
% részesítjük-e a nagyobb településeket
  
        % 1. Járások száma
        % 2. A nem járási székhelyen élő népesség száma a távolsággal súlyozva
        % 3. Járási székhelyen élő népesség száma
        
        score(1) = sum(vars == 1);
        score(3) = -(sum(vars .* (1:length(vars))));

        if prioritize
            score(1) = score(1) / score(3);
            score(2) = score(2) / score(3);
        end
end

function initialPopulation = commuteCreationFcn(GenomeLength, ~, options, expectedCount)
    initialPopulation = zeros(options.PopulationSize, GenomeLength);
    
    for i = 1:options.PopulationSize
        initialPopulation(i,ceil(abs(randn(expectedCount,1))/5*(GenomeLength))) = 1;
    end
end






