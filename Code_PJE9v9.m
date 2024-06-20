clc, close all
clear 
disp("Let's go !")


%% PULSE MODE

us = USWave ;
% Operating mode: 'Pulse-Echo' or 'Pitch-Catch'
    us.Mode = 'Pulse-Echo' ;
% Receiver input impedance: 50 Ohms, 100 Ohms, 200 Ohms or 6K Ohms
    us.InputImpedance = 50 ;
% Type of transmitter: 'Internal', 'Pulse' or 'External'
    us.TransmittingMode = 'Pulse' ;
% Transmission pulse width: 36 ns, 54 ns, 68 ns, 78 ns or 78ns+n*8ns
    us.PulseWidth = .5/1.7e6 ; 78e-9 + 1*8e-9 ;
% Input sampling frequency: 125 MHz, 75 MHz, 50 MHz, 25 MHz, 10 MHz, 5 MHz or 'External'  
    us.SamplingFrequency = 125e6 ;
% Delay value between the synchro signal and the beginning of the transmission signal
% Adjustable by step of 8 ns
    us.TransmittingDelay = 0e-9 ;
% Delay value between the synchro signal and the beginning of the sampling window  
% Adjustable by step of the sampling frequency
    us.SamplingDelay = 0e-5 ; 0/us.SamplingFrequency ;
% Amplifier gain range : 0 dB to 80 dB with a variation step of 1 dB 
    us.Gain = 0 ;
% Delay between the synchro signal and the beginning of the gain curve
% By sampling frequency step 
    us.GainCurveDelay = 0/us.SamplingFrequency ;
% Pulse Repetition Frequency in Hertz 
    us.PRF = 1000 ;
% Trigger mode for the transmission signals: 'Soft', 'Internal' or 'External' 
    us.Trigger = 'Internal' ;
% Transmission signal(s) which will be sent by the device   
% The sampling step of the digital analog converter is 8 ns (1/125 MHz)
% The SRAM memory can store 256 000 points
    %us.TransmittingCurve = zeros(1,256000) ;


%% PARAMETRES ARDUINO

a = arduino('COM7', 'Uno');
disp("Arduino found")

% Nombre de pas du moteur
stepsMotor = 2048;

% Broches de connexion du moteur
in1 = 'D8';
in2 = 'D9';
in3 = 'D10';
in4 = 'D11';

% Temps entre les pas, minimum 10 ms (Matlab ne va pas en dessous)
dl = 1e-4;


%% BOUCLE PRINCIPALE D'OPTIONS

while true
    disp('Choose an option:');
    disp(' ');
    disp('1. Move to a position');
    disp('2. Find incidence angle');
    disp('3. Run and plot');
    disp('4. Exit');
    disp(' ');
    choice = input('Enter your choice (1, 2, 3 or 4): ');
    disp(' ');
    if choice == 1
        prompt1 = "Angle desired (degrees)? ";
        stepsWanted = round(input(prompt1) * stepsMotor / 360);
        close all
        moveToPosition(a, in1, in2, in3, in4, dl, stepsWanted);
    elseif choice == 2
        prompt2 = "Angle to cover (degrees)? ";
        stepsWanted = round(input(prompt2) * stepsMotor / 360);
        close all
        FindIncidenceAngle(a, in1, in2, in3, in4, dl, us, stepsWanted, stepsMotor);
    elseif choice == 3
        prompt31 = "Angle to cover (degrees)? ";
        angleWanted = input(prompt31);
        prompt32 = "Number of measures? , (max : " + num2str(abs(floor(angleWanted*2048/360))) + "): ";
        numberOfMeasures = input(prompt32);
        close all
        dataMatrix = RunAndPlot(a, in1, in2, in3, in4, dl, us, angleWanted, numberOfMeasures, stepsMotor);
    elseif choice == 4
        break; % Terminer la boucle lorsque l'on choisit cette option
    else
        disp('Invalid choice. Please enter 1, 2, or 3.');
    end
end


%% MOTOR COMMAND

% Fonction pour envoyer des commandes à l'Arduino
function sendCommand(a, in1, in2, in3, in4, state)
    writeDigitalPin(a, in1, state(1));
    writeDigitalPin(a, in2, state(2));
    writeDigitalPin(a, in3, state(3));
    writeDigitalPin(a, in4, state(4));
end


%% MOVE TO POSITION

% Fonction pour déplacer le moteur à une position cible
function moveToPosition(a, in1, in2, in3, in4, dl, stepsWanted)

    stepsToMove = abs(stepsWanted);
    % Sélection des états en fonction du sens de déplacement
    if stepsWanted < 0
        % Initialisation des états pour les commandes en marche arrière
        states = [
            0 1 1 0;
            1 1 0 0;
            1 0 0 1;
            0 0 1 1
        ];
    else
        % Initialisation des états pour les commandes en marche avant
        states = [
            0 0 1 1;
            1 0 0 1;
            1 1 0 0;
            0 1 1 0
        ];
    end

    % Boucle pour atteindre la position cible
    for step = 1:stepsToMove
        % Calculer l'index en utilisant le reste de la division euclidienne
        stateIndex = mod(step-1, 4) + 1; % -1 pour commencer par l'index 1 au lieu de 0
        % Envoyer la commande à l'Arduino
        sendCommand(a, in1, in2, in3, in4, states(stateIndex, :));
        % Pause pour la synchronisation
        pause(dl);
    end
end


%% FIND INCIDENCE ANGLE

function FindIncidenceAngle(a, in1, in2, in3, in4, dl, us, stepsWanted, stepsMotor)
    
    stepsToMove = abs(stepsWanted);
    % Nombre de points retournés par us.getdata
    maxValuesMatrix = zeros(1, stepsToMove);

    % Sélection des états en fonction du sens de déplacement
    if stepsWanted < 0
        % Initialisation des états pour les commandes en marche arrière
        states = [
            0 1 1 0;
            1 1 0 0;
            1 0 0 1;
            0 0 1 1
        ];
    else
        % Initialisation des états pour les commandes en marche avant
        states = [
            0 0 1 1;
            1 0 0 1;
            1 1 0 0;
            0 1 1 0
        ];
    end

    % Afficher les en-têtes
    fprintf('%-10s%-15s\n', 'Step', 'Max Value');
    
    % Figure pour le tracé en temps réel
    figure;
    subplot(2, 1, 1);
    xlabel('Time (s)');
    ylabel('Signal Amplitude');
    title('Real-time Data and Maximum Detection');
    hold on;

    % Figure pour le tracé des valeurs maximales
    subplot(2, 1, 2);
    xlabel('Angle (degrees)');
    ylabel('Max Value (median)');
    title('Median of Maximum Values vs. Angle');
    hold on;
    grid on;
    
    angles = (0:stepsToMove-1) * (360 / stepsMotor);

    % Boucle pour atteindre la position cible
    for step = 1:stepsToMove
        % Calculer l'index en utilisant le reste de la division euclidienne
        stateIndex = mod(step - 1, 4) + 1; % -1 pour commencer par l'index 1 au lieu de 0
        % Envoyer la commande à l'Arduino
        sendCommand(a, in1, in2, in3, in4, states(stateIndex, :));
        % Pause pour la synchronisation
        pause(dl);

        % Variables pour stocker les maxima
        maxValues = zeros(10, 1);
        
        % Collecter les données de `us` pour 10 itérations
        for iter = 1:10
            data = us.getData();
            
            % Ignorer les 3000 premières valeurs
            maxValue = max(abs(data(3001:end)));

            % Stocker le maximum
            maxValues(iter) = maxValue;
        end
        
        % Calculer la médiane des maxima
        medianMaxValue = median(maxValues);
        
        % Sauvegarder les valeurs médianes
        maxValuesMatrix(step) = medianMaxValue;

        % Afficher le pas actuel et la valeur maximale correspondante
        fprintf('%-10d%-15.5f\n', step, medianMaxValue);

        % Tracer les données du dernier appel pour visualiser le graphe
        subplot(2, 1, 1);
        plot((0:numel(data)-1)/us.SamplingFrequency, data);
        hold on;
        [~, medianMaxIndex] = max(abs(data(3001:end)));
        medianMaxIndex = medianMaxIndex + 3000; % Ajuster l'indice
        % Indiquer où est le maximum sur le graphe
        plot((medianMaxIndex)/us.SamplingFrequency, medianMaxValue, 'ro'); 
        hold off;
        
        % Tracer le graphique des valeurs maximales au fur et à mesure
        subplot(2, 1, 2);
        plot(angles(1:step), maxValuesMatrix(1:step), 'b-');
        drawnow; % Mettre à jour le tracé en temps réel
    end

    % Trouver l'angle correspondant au maximum de maxValuesMatrix
    % Appliquer la moyenne glissante
    smoothedValues = movmean(maxValuesMatrix, 5);
    % Trouver l'indice du maximum dans les données lissées
    [~, maxIndex] = max(smoothedValues);
    stepsToReturn = -(stepsToMove - maxIndex);

    % Demander à l'utilisateur s'il souhaite revenir à l'angle optimal
    optimalAngle = angles(maxIndex);
    fprintf('Optimal angle found at %.2f degrees.\n', optimalAngle);
    prompt = 'Press Enter to go to optimal angle ';
    str = input(prompt, 's');
    
    if isempty(str)
        moveToPosition(a, in1, in2, in3, in4, dl, stepsToReturn);
    end
end


%% COMPLETE RUN

function dataMatrix = RunAndPlot(a, in1, in2, in3, in4, dl, us, angleWanted, numberOfMeasures, stepsMotor)

    stepsToMove = abs(round(angleWanted * stepsMotor / 360));
    % Si l'utilisateur donne un nombre de mesures trop élevé
    if numberOfMeasures > stepsToMove
        numberOfMeasures = stepsToMove;
        disp('Number of measures changed')
    end
    
    % Nombre de points retournés par us.getData
    dataMatrix = zeros(numberOfMeasures, 2^14);
    % Création des listes d'angles et de steps
    angleList = linspace(0, angleWanted, numberOfMeasures);
    stepList = round(abs(angleList * stepsMotor / 360));

    % Calcul des distances pour les graphes (divisé par 2 pour l'aller-retour et multiplié par 1000 pour obtenir des mm)
    distanceValues = linspace(0, 2^14 / us.SamplingFrequency * 1500 / 2 * 1000, 2^14);

    % Sélection des états en fonction du sens de déplacement
    if angleWanted < 0
        % Initialisation des états pour les commandes en marche arrière
        states = [
            0 1 1 0;
            1 1 0 0;
            1 0 0 1;
            0 0 1 1
        ];
    else
        % Initialisation des états pour les commandes en marche avant
        states = [
            0 0 1 1;
            1 0 0 1;
            1 1 0 0;
            0 1 1 0
        ];
    end

    % Afficher les en-têtes
    fprintf('%-10s%-15s\n', 'Step', 'Angle');
    
    % Création de la figure pour l'affichage en temps réel
    figure(1);
    % Affichage des données en temps réel
    subplot(2, 1, 1); 
    h = imagesc(angleList, distanceValues, transpose(dataMatrix));
    colorbar;
    title('Real time data');
    xlabel('Angle (degrees)');
    ylabel('Distance (mm)');
    
    % Graphique des lignes de dataMatrix
    subplot(2, 1, 2); 
    hold on;
    colormap = jet(numberOfMeasures); % Générer une colormap avec autant de couleurs que de mesures
    lineHandles = gobjects(1, numberOfMeasures); % Préallocation pour les handles des plots
    for i = 1:numberOfMeasures
        lineHandles(i) = plot(distanceValues, nan(1, 2^14), 'Color', colormap(i, :)); % Initialisation des courbes avec NaN et couleurs différentes
    end
    hold off;
    title('Graph of dataMatrix');
    xlabel('Distance (mm)');
    ylabel('Measures');

    % Création de la figure pour le graphique polaire
    figure(2);
    angles = (0:stepsToMove-1) * (360 / stepsMotor);
    polarPlotHandle = polarplot(deg2rad(angles), zeros(size(angles)), '-');
    title('Shape of the piece');
    
    % Boucle pour balayer l'angle voulu
    for step = 1:stepsToMove
        % Calculer l'index en utilisant le reste de la division euclidienne
        stateIndex = mod(step - 1, 4) + 1; % -1 pour commencer par l'index 1 au lieu de 0
        % Envoyer la commande à l'Arduino
        sendCommand(a, in1, in2, in3, in4, states(stateIndex, :));
        % Pause pour la synchronisation
        pause(dl);
        % Conserver les données uniquement si le step actuel est dans stepList
        if ismember(step, stepList)
            measureIndex = find(stepList == step);
            data = us.getData;
            dataMatrix(measureIndex, :) = data;
            
            % Supprimer les 3000 premières valeurs et trouver l'indice du maximum
            dataProcessed = abs(data(3001:end));
            [~, maxIndex] = max(dataProcessed);
            
            % Mise à jour des graphiques des lignes
            figure(1);  % Revenir à la première figure
            set(lineHandles(measureIndex), 'YData', data);
            % Mettre à jour l'affichage en temps réel
            set(h, 'CData', abs(transpose(dataMatrix)));
            % Mettre à jour le graphique polaire
            figure(2);  % Sélectionner la figure du graphique polaire
            polarPlotHandle.ThetaData(measureIndex) = deg2rad(angleList(measureIndex));
            polarPlotHandle.RData(measureIndex) = max(58-(2^14 - maxIndex) / us.SamplingFrequency * 1500 / 2 * 1000,0);
            drawnow;
            
            % Afficher le pas actuel et la valeur maximale correspondante
            fprintf('%-10d%-15.5f\n', step, angleList(measureIndex));
        end
    end
end
