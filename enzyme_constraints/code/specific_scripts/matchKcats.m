%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
 % kcats = matchKcats(model_data,org_name)
 % Matchs the model EC numbers and substrates to the BRENDA database, to
 % return the corresponding kcats for each reaction.
 %
% INPUT:    Model data structure (generated by getECnumbers.m)
 % OUTPUTS:  kcats, which contains:
 %           *forw.kcats:   kcat values for the forward reactions (mxn)
 %           *forw.org_s:   Number of matches for organism - substrate in
 %                          forward reaction (mxn)
 %           *forw.rest_s:  Number of matches for any organism - substrate
 %                          in forward reaction (mxn)
 %           *forw.org_ns:  Number of matches for organism - any substrate
 %                          in forward reaction (mxn)
 %           *forw.rest_ns: Number of matches for any organism - any
 %                          substrate in forward reaction (mxn)
 %           *forw.org_sa:  Number of matches for organism - using s.a.
 %                          in forward reaction (mxn)
 %           *forw.rest_sa: Number of matches for any organism - using s.a.
 %                          in forward reaction (mxn)
 %           *back.kcats:   kcat values for the backward reactions (mxn)
 %           *back.org_s:   Number of matches for organism - substrate in
 %                          backwards reaction (mxn)
 %           *back.rest_s:  Number of matches for any organism - substrate
 %                          in backwards reaction (mxn)
 %           *back.org_ns:  Number of matches for organism - any substrate
 %                          in backwards reaction (mxn)
 %           *back.rest_ns: Number of matches for any organism - any
 %                          substrate in backwards reaction (mxn)
 %           *back.org_sa:  Number of matches for organism - using s.a.
 %                          in backwards reaction (mxn)
 %           *back.rest_sa: Number of matches for any organism - using s.a.
 %                          in backwards reaction (mxn)
 %           *tot.queries:  The total amount of ECs matched (1x1)
 %           *tot.org_s:    The amount of ECs matched for the organism & the
 %                          substrate (1x1)
 %           *tot.rest_s:   The amount of ECs matched for any organism & the
 %                          substrate (1x1)
 %           *tot.org_ns:   The amount of ECs matched for the organism & any
 %                          substrate (1x1)
 %           *tot.rest_ns:  The amount of ECs matched for any organism & any
 %                          substrate (1x1)
 %           *tot.org_sa:   The amount of ECs matched for the organism & 
 %                          using s.a. (1x1)
 %           *tot.rest_sa:  The amount of ECs matched for any organism & 
 %                          using s.a. (1x1)
 % 
 % Benjamin J. Sanchez. Last edited: 2016-03-01
 % Ivan Domenzain.      Last edited: 2018-01-16
 %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
 function kcats = matchKcats(model_data, org_name)
 %Load BRENDA data:
 [KCATcell, SAcell] = loadBRENDAdata;
 
 %Creates a Structure with KEGG codes for organisms, names and taxonomical
 %distance matrix and extract the organism index in the KEGG struct
 phylDistStruct =  KEGG_struct;
 %Get the KEGG code for the model's organism
 org_index      = find_inKEGG(org_name,phylDistStruct.names);
 %Extract relevant info from model_data:
 substrates = model_data.substrates;
 products   = model_data.products;
 EC_numbers = model_data.EC_numbers;
 MWs        = model_data.MWs;
 model      = model_data.model;
 %Create initially empty outputs:
 [mM,nM]      = size(EC_numbers);
 forw.kcats   = zeros(mM,nM);
 forw.org_s   = zeros(mM,nM);
 forw.rest_s  = zeros(mM,nM);
 forw.org_ns  = zeros(mM,nM);
 forw.rest_ns = zeros(mM,nM);
 forw.org_sa  = zeros(mM,nM);
 forw.rest_sa = zeros(mM,nM);
 back.kcats   = zeros(mM,nM);
 back.org_s   = zeros(mM,nM);
 back.rest_s  = zeros(mM,nM);
 back.org_ns  = zeros(mM,nM);
 back.rest_ns = zeros(mM,nM);
 back.org_sa  = zeros(mM,nM);
 back.rest_sa = zeros(mM,nM);
 tot.queries  = 0;
 tot.org_s    = 0;
 tot.rest_s   = 0;
 tot.org_ns   = 0;
 tot.rest_ns  = 0;
 tot.org_sa   = 0;
 tot.rest_sa  = 0;
 tot.wc0      = 0;
 tot.wc1      = 0;
 tot.wc2      = 0;
 tot.wc3      = 0;
 tot.wc4      = 0;
 tot.matrix   = zeros(6,5);
 
 %Main loop: 
  for i = 1:mM
     %Match:
     for j = 1:nM
         EC = EC_numbers{i,j};
         MW = MWs(i,j);
         %Try to match direct reaction:
         if ~isempty(EC) && ~isempty(substrates{i,1})
              [forw,tot] = iterativeMatch(EC,MW,substrates(i,:),i,j,KCATcell,...
                                          forw,tot,model,org_name,...
                                          phylDistStruct,org_index,SAcell);
         end
         %Repeat for inverse reaction:
         if ~isempty(EC) && ~isempty(products{i,1})
             [back,tot] = iterativeMatch(EC,MW,products(i,:),i,j,KCATcell,...
                                         back,tot,model,org_name,...
                                         phylDistStruct,org_index,SAcell);
         end
     end
     %Display progress:
    if rem(i,10) == 0 || i == mM
        disp(['Matching kcats: Ready with rxn ' num2str(i)])
    end
 end
  
 kcats.forw = forw;
 kcats.back = back;
 kcats.tot  = tot;
 
 end
 %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
 function [dir,tot] =iterativeMatch(EC,MW,subs,i,j,KCATcell,dir,tot,model,...
                                    name,phylDist,org_index,SAcell)
 %Will iteratively try to match the EC number to some registry in BRENDA,
 %using each time one additional wildcard.
 
 EC      = strsplit(EC,' ');
 kcat    = zeros(size(EC));
 origin  = zeros(size(EC));
 matches = zeros(size(EC));
 wc_num  = ones(size(EC)).*1000;
 for k = 1:length(EC)
     success  = false;
     while ~success
         %Atempt match:
         [kcat(k),origin(k),matches(k)] = mainMatch(EC{k},MW,subs,KCATcell,...
                                                    model,i,name,phylDist,...
                                                    org_index,SAcell);
         %If any match found, ends. If not, introduces one extra wild card and
         %tries again:
         if origin(k) > 0
             success   = true;
             wc_num(k) = sum(EC{k}=='-');
         else
             dot_pos  = [2 strfind(EC{k},'.')];
             wild_num = sum(EC{k}=='-');
             wc_text  = '-.-.-.-';
             EC{k}    = [EC{k}(1:dot_pos(4-wild_num)) wc_text(1:2*wild_num+1)];
         end
     end
 end
 
 if sum(origin) > 0
     %For more than one EC: Choose the maximum value among the ones with the
     %less amount of wildcards and the better origin:
     best_pos   = (wc_num == min(wc_num));
     new_origin = origin(best_pos);
     best_pos   = (origin == min(new_origin(new_origin~=0)));
     max_pos    = find(kcat == max(kcat(best_pos)));
     wc_num     = wc_num(max_pos(1));
     origin     = origin(max_pos(1));
     matches    = matches(max_pos(1));
     kcat       = kcat(max_pos(1));
     
     %Update dir and tot:
     dir.kcats(i,j)   = kcat;
     dir.org_s(i,j)   = matches*(origin == 1);
     dir.rest_s(i,j)  = matches*(origin == 2);
     dir.org_ns(i,j)  = matches*(origin == 3);
     dir.org_sa(i,j)  = matches*(origin == 4);
     dir.rest_ns(i,j) = matches*(origin == 5);    
     dir.rest_sa(i,j) = matches*(origin == 6);
     tot.org_s        = tot.org_s   + (origin == 1);
     tot.rest_s       = tot.rest_s  + (origin == 2);
     tot.org_ns       = tot.org_ns  + (origin == 3);
     tot.org_sa       = tot.org_sa  + (origin == 4);
     tot.rest_ns      = tot.rest_ns + (origin == 5);    
     tot.rest_sa      = tot.rest_sa + (origin == 6);
     tot.wc0          = tot.wc0     + (wc_num == 0);
     tot.wc1          = tot.wc1     + (wc_num == 1);
     tot.wc2          = tot.wc2     + (wc_num == 2);
     tot.wc3          = tot.wc3     + (wc_num == 3);
     tot.wc4          = tot.wc4     + (wc_num == 4);
     tot.queries      = tot.queries + 1;
     tot.matrix(origin,wc_num+1) = tot.matrix(origin,wc_num+1) + 1;
 end
 
 end
 %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
 
 function [kcat,origin,matches] = mainMatch(EC,MW,subs,KCATcell,model,i,...
                                      name,phylDist,org_index,SAcell)
                                                                   
 % Matching function prioritizing organism and substrate specificity when 
 % available.
 
 origin = 0;
 %First try to match organism and substrate:
 [kcat,matches] = matchKcat(EC,MW,subs,KCATcell,name,true,false,model,i,...
                            phylDist,org_index,SAcell);                      
 if matches > 0
     origin = 1;
 %If no match, try the closest organism but match the substrate:
 else   
    [kcat,matches] = matchKcat(EC,MW,subs,KCATcell,'',true,false,model,i,...
                               phylDist,org_index,SAcell);
     if matches > 0
         origin = 2;
     %If no match, try to match organism but with any substrate:
     else
         [kcat,matches] = matchKcat(EC,MW,subs,KCATcell,name,false,false,...
                                    model,i,phylDist,org_index,SAcell);
         if matches > 0
             origin = 3;
         %If no match, try to match organism but for any substrate (SA*MW):
         else
              [kcat,matches] = matchKcat(EC,MW,subs,KCATcell,name,false,...
                                         true,model,i,phylDist,org_index,...
                                         SAcell);
              if matches > 0
                  origin = 4; 
             %If no match, try any organism and any substrate:
              else
                 [kcat,matches] = matchKcat(EC,MW,subs,KCATcell,'',false,...
                                            false,model,i,phylDist,...
                                            org_index,SAcell);
                 if matches > 0
                     origin = 5;
                 %Again if no match, look for any org and SA*MW    
                  else
                      [kcat,matches] = matchKcat(EC,MW,subs,KCATcell,'',...
                                                 false,true,model,i,phylDist,...
                                                 org_index, SAcell);
                      if matches > 0
                          origin = 6;
                      end
                 end
                         
              end    
         end
     end
 end
 end
 %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
 function [kcat,matches] = matchKcat(EC,MW,subs,KCATcell,organism,...
                                     substrate,SA,model,i,phylDist,...
                                                         org_index,SAcell)
                  
 %Will go through BRENDA and will record any match. Afterwards, it will
 %return the average value and the number of matches attained.
 kcat    = [];
 matches = 0;
 %Relaxes matching if wild cards are present:
 wild     = false;
 wild_pos = strfind(EC,'-');
 if ~isempty(wild_pos)
     EC   = EC(1:wild_pos(1)-1);
     wild = true;
 end

 if SA
     EC_indexes = extract_indexes(EC,SAcell{1},[],SAcell{2},subs,substrate,...
                                  organism,org_index,phylDist,wild);
     kcat       = SAcell{3}(EC_indexes);
     org_cell   = SAcell{2}(EC_indexes);
     MW_BRENDA  = SAcell{4}(EC_indexes);
 else
     EC_indexes = extract_indexes(EC,KCATcell{1},KCATcell{2},KCATcell{3},...
                                  subs,substrate,organism,org_index,...
                                                      phylDist,wild);
     if substrate
         for j = 1:length(EC_indexes)
             indx = EC_indexes(j);
             for k = 1:length(subs)
                 l = logical(strcmpi(model.metNames,subs{k}).*(model.S(:,i)~=0));
                 if ~isempty(subs{k}) && strcmpi(subs{k},KCATcell{2}(indx))
                     if KCATcell{4}(indx) > 0 
                         coeff = min(abs(model.S(l,i)));
                         kcat  = [kcat;KCATcell{4}(indx)/coeff];
                     end
                 end
             end
         end
     else
         kcat = KCATcell{4}(EC_indexes);
     end
 end                         
 %Return maximum value:
 if isempty(kcat)
     kcat = 0;
 else
     matches        = length(kcat);
     [kcat,MaxIndx] = max(kcat);
%      if SA
%          % If the match correspond to a SA*Mw value for the model's
%          % organism the kcat will be corrected with the sequence based Mw
%          if strcmpi(organism,org_cell(MaxIndx))
%              kcat = kcat*MW/MW_BRENDA(MaxIndx);
%          end
%      end        
 end
 %Avoid SA*Mw values over the diffusion limit rate  [Bar-Even et al. 2011]
 if kcat>(1E7*3600)
     kcat = 1E7*3600;
 end
 end
 %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
 %Extract the indexes of the entries in the BRENDA data that meet the 
 %conditions specified by the search criteria
 function EC_indexes = extract_indexes(EC,EC_cell,subs_cell,orgs_cell,subs,...
                                       substrate,organism, org_index,...
                                       phylDist,wild)
 
 EC_indexes = [];
 if wild
   for j=1:length(EC_cell)
        if strfind(EC_cell{j},EC)==1
            EC_indexes = [EC_indexes,j];
        end
    end   
 else
    EC_indexes = transpose(find(strcmpi(EC,EC_cell)));  
 end
 %If substrate=true then it will extract only the substrates appereances 
 %indexes in the EC subset from the BRENDA cell array
 if substrate
     Subs_indexes = [];
     for l = 1:length(subs)
         if ~isempty(subs(l))
             Subs_indexes = horzcat(Subs_indexes,EC_indexes(strcmpi(subs(l),...
                                    subs_cell(EC_indexes))));          
         end
     end
     EC_indexes = Subs_indexes;    
 end
 
 EC_orgs = orgs_cell(EC_indexes);
 %If specific organism values are requested looks for all the organism
 %repetitions on the subset BRENDA cell array(EC_indexes)
 if string(organism) ~= ''  
     EC_indexes = EC_indexes(strcmpi(string(organism),EC_orgs));
 
 %If KEGG code was assigned to the organism (model) then it will look for   
 %the Kcat value for the closest organism
 elseif org_index~='*' %&& org_index~=''
     KEGG_indexes = [];temp = [];
     
     %For relating a phyl dist between the modelled organism and the organisms
     %on the BRENDA cell array it should search for a KEGG code for each of 
     %these 
     for j=1:length(EC_indexes)
         %Assigns a KEGG index for those found on the KEGG struct
         orgs_index = find(strcmpi(orgs_cell(EC_indexes(j)),phylDist.names),1);
         if ~isempty(orgs_index)
             KEGG_indexes = [KEGG_indexes; orgs_index];
             temp         = [temp;EC_indexes(j)];
             %For values related to organisms without KEGG code, then it will
             %look for KEGG code for the first organism with the same genus
         else
             if isempty(orgs_index)
                 org   = orgs_cell{EC_indexes(j)};
                 genus = org(1:strfind(org,' ')-1);
                 orgs_index = find(contains(phylDist.names,genus),1);
                 if ~isempty(orgs_index)
                     KEGG_indexes = [KEGG_indexes;orgs_index];
                     temp         = [temp;EC_indexes(j)];
                 end
             end
         end
     end
     %Update the EC_indexes cell array
     EC_indexes = temp;
     %Looks for the taxonomically closest organism and saves the index of
     %its appearences in the BRENDA cell
     if ~isempty(EC_indexes)
         distances  = num2cell(phylDist.distMat(org_index,:));
         distances  = distances(KEGG_indexes);
         EC_indexes = EC_indexes(cell2mat(distances) ==...
                                                 min(cell2mat(distances)));                     
     end
 end
 
 end 
 %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
 function org_index = find_inKEGG(org_name,names)
     org_index      = find(strcmpi(org_name,names));
     if isempty(org_index)
         i=1;
         while isempty(org_index) && i<length(names)
             str = names{i};
             if strcmpi(org_name(1:strfind(org_name,' ')-1),...
                 str(1:strfind(str,' ')-1))
                 org_index = i;
             end
             i = i+1;
         end
         if isempty(org_index);org_index = '*';end
     end
 end
 %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
 function phylDistStruct =  KEGG_struct
     load('../../databases/PhylDist.mat')
     phylDistStruct.ids   = transpose(phylDistStruct.ids);
     phylDistStruct.names = transpose(phylDistStruct.names);
     
     for i=1:length(phylDistStruct.names)
         pos = strfind(phylDistStruct.names{i}, ' (');
         if ~isempty(pos)
             phylDistStruct.names{i} = phylDistStruct.names{i}(1:pos-1);
         end
     end
 end
