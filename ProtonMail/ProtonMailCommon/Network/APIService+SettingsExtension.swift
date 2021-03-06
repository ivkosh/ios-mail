//
//  APIService+SettingsExtension.swift
//  ProtonMail
//
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of ProtonMail.
//
//  ProtonMail is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonMail is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonMail.  If not, see <https://www.gnu.org/licenses/>.


import Foundation

//Settings extension
extension APIService {
    
    fileprivate struct SettingPath {
        static let base = Constants.App.API_PATH + "/settings/mail"
    }
    
    //TODO::Swift
    func settingUpdateSignature(_ signature: String, authCredential: AuthCredential?, completion: @escaping CompletionBlock) {
        let path = SettingPath.base + "/signature"
        let parameters = ["Signature" : signature]
        request(method: .put, path: path, parameters: parameters, headers: ["x-pm-apiversion": 3], customAuthCredential: authCredential, completion: completion)
    }
}


